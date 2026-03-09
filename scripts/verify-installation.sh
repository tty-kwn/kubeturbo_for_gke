#!/bin/bash

# Kubeturbo Installation Verification Script
# このスクリプトは Kubeturbo のインストールを検証します

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト値
NAMESPACE="turbo"
VERBOSE=false

# 使用方法の表示
usage() {
    cat << EOF
使用方法: $0 [オプション]

オプション:
    --namespace NS      検証する namespace [デフォルト: turbo]
    --verbose           詳細な出力を表示
    -h, --help          このヘルプメッセージを表示

例:
    $0
    $0 --namespace turbo --verbose

EOF
    exit 1
}

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${NC}    $1"
    fi
}

# 引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "不明なオプション: $1"
            usage
            ;;
    esac
done

# チェック結果のカウンター
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# チェック関数
check_pass() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    log_success "$1"
}

check_fail() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    log_error "$1"
}

check_warn() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    log_warn "$1"
}

# ヘッダー表示
echo "========================================"
echo "  Kubeturbo Installation Verification"
echo "========================================"
echo ""
echo "Namespace: $NAMESPACE"
echo ""

# 1. 前提条件のチェック
log_info "1. 前提条件をチェックしています..."

# kubectl のチェック
if command -v kubectl &> /dev/null; then
    check_pass "kubectl がインストールされています"
    log_verbose "$(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    check_fail "kubectl が見つかりません"
fi

# helm のチェック
if command -v helm &> /dev/null; then
    check_pass "helm がインストールされています"
    log_verbose "$(helm version --short)"
else
    check_warn "helm が見つかりません（オプション）"
fi

# クラスタへの接続確認
if kubectl cluster-info &> /dev/null; then
    check_pass "Kubernetes クラスタに接続できます"
    if [ "$VERBOSE" = true ]; then
        log_verbose "$(kubectl cluster-info | head -n 1)"
    fi
else
    check_fail "Kubernetes クラスタに接続できません"
    exit 1
fi

echo ""

# 2. Namespace のチェック
log_info "2. Namespace をチェックしています..."

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    check_pass "Namespace '$NAMESPACE' が存在します"
else
    check_fail "Namespace '$NAMESPACE' が見つかりません"
    exit 1
fi

echo ""

# 3. Pod のチェック
log_info "3. Pod の状態をチェックしています..."

POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --no-headers 2>/dev/null | wc -l)

if [ "$POD_COUNT" -eq 0 ]; then
    check_fail "Kubeturbo Pod が見つかりません"
else
    check_pass "Kubeturbo Pod が見つかりました（$POD_COUNT 個）"
    
    # Pod の状態確認
    POD_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    
    if [ "$POD_STATUS" = "Running" ]; then
        check_pass "Pod のステータス: Running"
    else
        check_fail "Pod のステータス: $POD_STATUS"
    fi
    
    # Ready 状態の確認
    READY_STATUS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    
    if [ "$READY_STATUS" = "True" ]; then
        check_pass "Pod は Ready 状態です"
    else
        check_fail "Pod は Ready 状態ではありません"
    fi
    
    # 再起動回数の確認
    RESTART_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
    
    if [ "$RESTART_COUNT" -eq 0 ]; then
        check_pass "Pod の再起動回数: 0"
    elif [ "$RESTART_COUNT" -le 3 ]; then
        check_warn "Pod の再起動回数: $RESTART_COUNT（少し多いです）"
    else
        check_fail "Pod の再起動回数: $RESTART_COUNT（多すぎます）"
    fi
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        log_verbose "Pod の詳細:"
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo | sed 's/^/    /'
    fi
fi

echo ""

# 4. ログのチェック
log_info "4. ログをチェックしています..."

if [ "$POD_COUNT" -gt 0 ]; then
    # エラーログの確認
    ERROR_COUNT=$(kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --tail=100 2>/dev/null | grep -i "error\|fatal" | wc -l)
    
    if [ "$ERROR_COUNT" -eq 0 ]; then
        check_pass "ログにエラーはありません"
    else
        check_warn "ログに $ERROR_COUNT 個のエラーが見つかりました"
        if [ "$VERBOSE" = true ]; then
            log_verbose "最近のエラー:"
            kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --tail=100 2>/dev/null | grep -i "error\|fatal" | tail -n 5 | sed 's/^/    /'
        fi
    fi
    
    # 接続成功のログ確認
    if kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --tail=200 2>/dev/null | grep -qi "connected\|registered"; then
        check_pass "Turbonomic サーバーへの接続が確認できました"
    else
        check_warn "Turbonomic サーバーへの接続ログが見つかりません"
    fi
    
    # 検出ログの確認
    if kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --tail=200 2>/dev/null | grep -qi "discovery"; then
        check_pass "クラスタ検出が実行されています"
    else
        check_warn "クラスタ検出のログが見つかりません"
    fi
fi

echo ""

# 5. Service Account のチェック
log_info "5. Service Account をチェックしています..."

if kubectl get serviceaccount kubeturbo -n "$NAMESPACE" &> /dev/null; then
    check_pass "Service Account 'kubeturbo' が存在します"
    
    # Workload Identity のアノテーション確認
    WI_ANNOTATION=$(kubectl get serviceaccount kubeturbo -n "$NAMESPACE" -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
    
    if [ -n "$WI_ANNOTATION" ]; then
        check_pass "Workload Identity が設定されています"
        log_verbose "GCP Service Account: $WI_ANNOTATION"
    else
        check_warn "Workload Identity が設定されていません（オプション）"
    fi
else
    check_fail "Service Account 'kubeturbo' が見つかりません"
fi

echo ""

# 6. RBAC のチェック
log_info "6. RBAC 権限をチェックしています..."

# ClusterRole の確認
if kubectl get clusterrole kubeturbo &> /dev/null; then
    check_pass "ClusterRole 'kubeturbo' が存在します"
else
    check_fail "ClusterRole 'kubeturbo' が見つかりません"
fi

# ClusterRoleBinding の確認
if kubectl get clusterrolebinding kubeturbo &> /dev/null; then
    check_pass "ClusterRoleBinding 'kubeturbo' が存在します"
else
    check_fail "ClusterRoleBinding 'kubeturbo' が見つかりません"
fi

# 権限の確認
if kubectl auth can-i get nodes --as=system:serviceaccount:$NAMESPACE:kubeturbo &> /dev/null; then
    check_pass "ノードへのアクセス権限があります"
else
    check_fail "ノードへのアクセス権限がありません"
fi

if kubectl auth can-i get pods --as=system:serviceaccount:$NAMESPACE:kubeturbo &> /dev/null; then
    check_pass "Pod へのアクセス権限があります"
else
    check_fail "Pod へのアクセス権限がありません"
fi

echo ""

# 7. Secret のチェック
log_info "7. Secret をチェックしています..."

if kubectl get secret turbonomic-credentials -n "$NAMESPACE" &> /dev/null; then
    check_pass "Secret 'turbonomic-credentials' が存在します"
    
    # Secret の内容確認
    if kubectl get secret turbonomic-credentials -n "$NAMESPACE" -o jsonpath='{.data.turboUsername}' &> /dev/null; then
        check_pass "Secret に turboUsername が含まれています"
    else
        check_fail "Secret に turboUsername が含まれていません"
    fi
    
    if kubectl get secret turbonomic-credentials -n "$NAMESPACE" -o jsonpath='{.data.turboPassword}' &> /dev/null; then
        check_pass "Secret に turboPassword が含まれています"
    else
        check_fail "Secret に turboPassword が含まれていません"
    fi
else
    check_fail "Secret 'turbonomic-credentials' が見つかりません"
fi

echo ""

# 8. リソース使用状況のチェック
log_info "8. リソース使用状況をチェックしています..."

if command -v kubectl &> /dev/null && kubectl top pod -n "$NAMESPACE" &> /dev/null; then
    RESOURCE_INFO=$(kubectl top pod -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --no-headers 2>/dev/null)
    
    if [ -n "$RESOURCE_INFO" ]; then
        check_pass "リソース使用状況を取得できました"
        if [ "$VERBOSE" = true ]; then
            log_verbose "リソース使用状況:"
            echo "$RESOURCE_INFO" | sed 's/^/    /'
        fi
    else
        check_warn "リソース使用状況を取得できませんでした"
    fi
else
    check_warn "Metrics Server が利用できません（オプション）"
fi

echo ""

# 9. Helm リリースのチェック（オプション）
if command -v helm &> /dev/null; then
    log_info "9. Helm リリースをチェックしています..."
    
    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q kubeturbo; then
        check_pass "Helm リリース 'kubeturbo' が見つかりました"
        
        if [ "$VERBOSE" = true ]; then
            log_verbose "Helm リリース情報:"
            helm list -n "$NAMESPACE" | grep kubeturbo | sed 's/^/    /'
        fi
    else
        check_warn "Helm リリース 'kubeturbo' が見つかりません（手動インストールの可能性）"
    fi
    
    echo ""
fi

# 結果のサマリー
echo "========================================"
echo "  検証結果サマリー"
echo "========================================"
echo ""
echo "総チェック数: $TOTAL_CHECKS"
echo -e "${GREEN}成功: $PASSED_CHECKS${NC}"
echo -e "${YELLOW}警告: $WARNING_CHECKS${NC}"
echo -e "${RED}失敗: $FAILED_CHECKS${NC}"
echo ""

# 最終判定
if [ "$FAILED_CHECKS" -eq 0 ]; then
    if [ "$WARNING_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}✓ すべてのチェックに合格しました！${NC}"
        echo ""
        echo "次のステップ:"
        echo "1. Turbonomic UI でターゲットを確認してください"
        echo "2. メトリクスが収集されていることを確認してください"
        echo "3. 詳細は docs/04-verification.md を参照してください"
        EXIT_CODE=0
    else
        echo -e "${YELLOW}⚠ 一部のチェックで警告がありますが、基本的な動作は問題ありません${NC}"
        echo ""
        echo "警告の内容を確認し、必要に応じて対処してください。"
        echo "詳細は docs/05-troubleshooting.md を参照してください。"
        EXIT_CODE=0
    fi
else
    echo -e "${RED}✗ 一部のチェックに失敗しました${NC}"
    echo ""
    echo "失敗した項目を確認し、修正してください。"
    echo "詳細は docs/05-troubleshooting.md を参照してください。"
    echo ""
    echo "デバッグ情報:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kubeturbo"
    echo "  kubectl describe pod -n $NAMESPACE -l app.kubernetes.io/name=kubeturbo"
    EXIT_CODE=1
fi

echo ""
exit $EXIT_CODE

# Made with Bob

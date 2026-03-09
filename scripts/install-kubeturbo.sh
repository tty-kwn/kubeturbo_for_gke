#!/bin/bash

# Kubeturbo Installation Script for GKE
# このスクリプトは Kubeturbo を GKE クラスタにインストールします

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# デフォルト値
NAMESPACE="turbo"
CLUSTER_TYPE="standard"
HELM_RELEASE_NAME="kubeturbo"

# 使用方法の表示
usage() {
    cat << EOF
使用方法: $0 [オプション]

オプション:
    --cluster-type TYPE         GKE クラスタタイプ (standard または autopilot) [デフォルト: standard]
    --turbo-server URL          Turbonomic サーバーの URL (必須)
    --cluster-name NAME         クラスタ名 (必須)
    --project-id ID             GCP プロジェクト ID (Workload Identity 使用時に必須)
    --namespace NS              インストール先の namespace [デフォルト: turbo]
    --turbo-username USER       Turbonomic ユーザー名 [デフォルト: administrator]
    --turbo-password PASS       Turbonomic パスワード (必須)
    --helm-release NAME         Helm リリース名 [デフォルト: kubeturbo]
    --dry-run                   ドライランモード（実際にはインストールしない）
    -h, --help                  このヘルプメッセージを表示

例:
    # Standard GKE へのインストール
    $0 --cluster-type standard \\
       --turbo-server https://turbonomic.example.com \\
       --cluster-name my-gke-cluster \\
       --project-id my-project \\
       --turbo-password 'mypassword'

    # Autopilot GKE へのインストール
    $0 --cluster-type autopilot \\
       --turbo-server https://turbonomic.example.com \\
       --cluster-name my-autopilot-cluster \\
       --project-id my-project \\
       --turbo-password 'mypassword'

EOF
    exit 1
}

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 引数の解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --cluster-type)
            CLUSTER_TYPE="$2"
            shift 2
            ;;
        --turbo-server)
            TURBO_SERVER="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --project-id)
            PROJECT_ID="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --turbo-username)
            TURBO_USERNAME="$2"
            shift 2
            ;;
        --turbo-password)
            TURBO_PASSWORD="$2"
            shift 2
            ;;
        --helm-release)
            HELM_RELEASE_NAME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
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

# 必須パラメータのチェック
if [ -z "$TURBO_SERVER" ]; then
    log_error "Turbonomic サーバー URL が指定されていません (--turbo-server)"
    usage
fi

if [ -z "$CLUSTER_NAME" ]; then
    log_error "クラスタ名が指定されていません (--cluster-name)"
    usage
fi

if [ -z "$TURBO_PASSWORD" ]; then
    log_error "Turbonomic パスワードが指定されていません (--turbo-password)"
    usage
fi

# デフォルト値の設定
TURBO_USERNAME=${TURBO_USERNAME:-"administrator"}

# クラスタタイプの検証
if [ "$CLUSTER_TYPE" != "standard" ] && [ "$CLUSTER_TYPE" != "autopilot" ]; then
    log_error "無効なクラスタタイプ: $CLUSTER_TYPE (standard または autopilot を指定してください)"
    exit 1
fi

# values ファイルのパス
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALUES_FILE="$PROJECT_ROOT/values/values-${CLUSTER_TYPE}-gke.yaml"

if [ ! -f "$VALUES_FILE" ]; then
    log_error "values ファイルが見つかりません: $VALUES_FILE"
    exit 1
fi

# ヘッダー表示
echo "========================================"
echo "  Kubeturbo Installation Script"
echo "========================================"
echo ""
echo "設定:"
echo "  クラスタタイプ: $CLUSTER_TYPE"
echo "  Turbonomic サーバー: $TURBO_SERVER"
echo "  クラスタ名: $CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo "  Helm リリース名: $HELM_RELEASE_NAME"
echo "  Values ファイル: $VALUES_FILE"
if [ -n "$PROJECT_ID" ]; then
    echo "  GCP プロジェクト ID: $PROJECT_ID"
fi
if [ "$DRY_RUN" = true ]; then
    echo "  モード: ドライラン"
fi
echo ""

# 確認
if [ "$DRY_RUN" != true ]; then
    read -p "この設定でインストールを続行しますか? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_info "インストールをキャンセルしました"
        exit 0
    fi
fi

# 前提条件のチェック
log_info "前提条件をチェックしています..."

# kubectl のチェック
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl が見つかりません。インストールしてください。"
    exit 1
fi

# helm のチェック
if ! command -v helm &> /dev/null; then
    log_error "helm が見つかりません。インストールしてください。"
    exit 1
fi

# クラスタへの接続確認
if ! kubectl cluster-info &> /dev/null; then
    log_error "Kubernetes クラスタに接続できません。kubectl の設定を確認してください。"
    exit 1
fi

log_info "✓ 前提条件のチェック完了"

# Namespace の作成
log_info "Namespace を作成しています..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] kubectl create namespace $NAMESPACE"
else
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warn "Namespace '$NAMESPACE' は既に存在します"
    else
        kubectl create namespace "$NAMESPACE"
        log_info "✓ Namespace '$NAMESPACE' を作成しました"
    fi
fi

# Secret の作成
log_info "Turbonomic 認証情報の Secret を作成しています..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] kubectl create secret generic turbonomic-credentials -n $NAMESPACE"
else
    if kubectl get secret turbonomic-credentials -n "$NAMESPACE" &> /dev/null; then
        log_warn "Secret 'turbonomic-credentials' は既に存在します。削除して再作成します。"
        kubectl delete secret turbonomic-credentials -n "$NAMESPACE"
    fi
    
    kubectl create secret generic turbonomic-credentials \
        -n "$NAMESPACE" \
        --from-literal=turboUsername="$TURBO_USERNAME" \
        --from-literal=turboPassword="$TURBO_PASSWORD"
    
    log_info "✓ Secret を作成しました"
fi

# Helm リポジトリの追加
log_info "Helm リポジトリを追加しています..."
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] helm repo add turbonomic https://turbonomic.github.io/t8c-install"
else
    if helm repo list | grep -q "turbonomic"; then
        log_warn "Helm リポジトリ 'turbonomic' は既に追加されています"
    else
        helm repo add turbonomic https://turbonomic.github.io/t8c-install
        log_info "✓ Helm リポジトリを追加しました"
    fi
    
    helm repo update
    log_info "✓ Helm リポジトリを更新しました"
fi

# Helm インストール
log_info "Kubeturbo をインストールしています..."

HELM_ARGS=(
    "$HELM_RELEASE_NAME"
    "turbonomic/kubeturbo"
    "--namespace" "$NAMESPACE"
    "-f" "$VALUES_FILE"
    "--set" "serverMeta.turboServer=$TURBO_SERVER"
    "--set" "targetConfig.targetName=$CLUSTER_NAME"
)

# Workload Identity の設定（PROJECT_ID が指定されている場合）
if [ -n "$PROJECT_ID" ]; then
    GSA_EMAIL="kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com"
    HELM_ARGS+=(
        "--set" "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account=$GSA_EMAIL"
    )
fi

if [ "$DRY_RUN" = true ]; then
    HELM_ARGS+=("--dry-run" "--debug")
    log_info "[DRY-RUN] helm install ${HELM_ARGS[*]}"
    helm install "${HELM_ARGS[@]}"
else
    helm install "${HELM_ARGS[@]}"
    log_info "✓ Kubeturbo をインストールしました"
fi

# インストール後の確認
if [ "$DRY_RUN" != true ]; then
    log_info "インストールを確認しています..."
    
    # Pod の起動を待機
    log_info "Pod の起動を待機しています（最大 2 分）..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=kubeturbo \
        -n "$NAMESPACE" \
        --timeout=120s || {
        log_warn "Pod の起動に時間がかかっています。手動で確認してください。"
        log_info "確認コマンド: kubectl get pods -n $NAMESPACE"
    }
    
    # Pod の状態表示
    echo ""
    log_info "Pod の状態:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo
    
    # ログの表示
    echo ""
    log_info "最新のログ（最後の 20 行）:"
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=kubeturbo --tail=20 || true
fi

# 完了メッセージ
echo ""
echo "========================================"
if [ "$DRY_RUN" = true ]; then
    log_info "ドライラン完了"
else
    log_info "インストール完了！"
fi
echo "========================================"
echo ""

if [ "$DRY_RUN" != true ]; then
    echo "次のステップ:"
    echo "1. Pod の状態を確認:"
    echo "   kubectl get pods -n $NAMESPACE"
    echo ""
    echo "2. ログを確認:"
    echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kubeturbo -f"
    echo ""
    echo "3. Turbonomic UI でターゲットを確認:"
    echo "   $TURBO_SERVER"
    echo ""
    echo "詳細なドキュメント:"
    echo "- 動作確認: docs/04-verification.md"
    echo "- トラブルシューティング: docs/05-troubleshooting.md"
fi

exit 0

# Made with Bob

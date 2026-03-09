# インストール手順

このガイドでは、Kubeturbo を GKE クラスタにインストールする手順を説明します。

## 目次

- [前提条件の確認](#前提条件の確認)
- [Helm リポジトリの設定](#helm-リポジトリの設定)
- [Standard GKE へのインストール](#standard-gke-へのインストール)
- [Autopilot GKE へのインストール](#autopilot-gke-へのインストール)
- [インストールの確認](#インストールの確認)
- [次のステップ](#次のステップ)

---

## 前提条件の確認

インストールを開始する前に、[事前準備](01-prerequisites.md) が完了していることを確認してください。

### クイックチェック

```bash
# kubectl の接続確認
kubectl cluster-info

# Helm のバージョン確認
helm version

# namespace の確認
kubectl get namespace turbo

# Secret の確認
kubectl get secret turbonomic-credentials -n turbo
```

---

## Helm リポジトリの設定

### 1. Turbonomic Helm リポジトリの追加

```bash
# Helm リポジトリの追加
helm repo add turbonomic https://turbonomic.github.io/t8c-install

# リポジトリの更新
helm repo update

# リポジトリの確認
helm repo list
```

### 2. 利用可能なチャートバージョンの確認

```bash
# 利用可能なバージョンの一覧
helm search repo turbonomic/kubeturbo --versions

# 最新バージョンの詳細
helm show chart turbonomic/kubeturbo

# values.yaml の確認
helm show values turbonomic/kubeturbo > /tmp/kubeturbo-default-values.yaml
```

---

## Standard GKE へのインストール

### 方法 1: values ファイルを使用したインストール（推奨）

#### 1. values ファイルの準備

このリポジトリの `values/values-standard-gke.yaml` をコピーして編集します：

```bash
# values ファイルをコピー
cp values/values-standard-gke.yaml /tmp/my-kubeturbo-values.yaml

# エディタで編集
vim /tmp/my-kubeturbo-values.yaml
```

**必須の編集項目:**

```yaml
serverMeta:
  turboServer: "https://your-turbonomic-server.example.com"  # ← 変更

targetConfig:
  targetName: "your-gke-cluster-name"  # ← 変更

restAPIConfig:
  opsManagerUserSecret: "turbonomic-credentials"  # ← Secret 名を確認
```

**Workload Identity を使用する場合:**

```yaml
serviceAccount:
  create: true
  annotations:
    iam.gke.io/gcp-service-account: "kubeturbo@YOUR_PROJECT_ID.iam.gserviceaccount.com"  # ← 変更
```

#### 2. インストールの実行

```bash
# Helm でインストール
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f /tmp/my-kubeturbo-values.yaml

# インストール状態の確認
helm status kubeturbo -n turbo
```

### 方法 2: コマンドラインでパラメータを指定

```bash
# 環境変数の設定
export TURBO_SERVER="https://your-turbonomic-server.example.com"
export CLUSTER_NAME="your-gke-cluster-name"
export PROJECT_ID="your-gcp-project-id"

# インストール
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f values/values-standard-gke.yaml \
  --set serverMeta.turboServer=${TURBO_SERVER} \
  --set targetConfig.targetName=${CLUSTER_NAME} \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 方法 3: スクリプトを使用したインストール

```bash
# インストールスクリプトの実行
./scripts/install-kubeturbo.sh \
  --cluster-type standard \
  --turbo-server "https://your-turbonomic-server.example.com" \
  --cluster-name "your-gke-cluster-name" \
  --project-id "your-gcp-project-id"
```

---

## Autopilot GKE へのインストール

Autopilot GKE では、セキュリティとリソースの制約が厳しいため、専用の values ファイルを使用します。

### 方法 1: values ファイルを使用したインストール（推奨）

#### 1. values ファイルの準備

```bash
# values ファイルをコピー
cp values/values-autopilot-gke.yaml /tmp/my-kubeturbo-autopilot-values.yaml

# エディタで編集
vim /tmp/my-kubeturbo-autopilot-values.yaml
```

**必須の編集項目:**

```yaml
serverMeta:
  turboServer: "https://your-turbonomic-server.example.com"  # ← 変更

targetConfig:
  targetName: "your-gke-autopilot-cluster-name"  # ← 変更

restAPIConfig:
  opsManagerUserSecret: "turbonomic-credentials"  # ← Secret 名を確認

serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "kubeturbo@YOUR_PROJECT_ID.iam.gserviceaccount.com"  # ← 変更（必須）
```

**重要:** Autopilot では Workload Identity の使用が必須です。

#### 2. インストールの実行

```bash
# Helm でインストール
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f /tmp/my-kubeturbo-autopilot-values.yaml

# インストール状態の確認
helm status kubeturbo -n turbo
```

### 方法 2: コマンドラインでパラメータを指定

```bash
# 環境変数の設定
export TURBO_SERVER="https://your-turbonomic-server.example.com"
export CLUSTER_NAME="your-gke-autopilot-cluster-name"
export PROJECT_ID="your-gcp-project-id"

# インストール
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f values/values-autopilot-gke.yaml \
  --set serverMeta.turboServer=${TURBO_SERVER} \
  --set targetConfig.targetName=${CLUSTER_NAME} \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"="kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 方法 3: スクリプトを使用したインストール

```bash
# インストールスクリプトの実行
./scripts/install-kubeturbo.sh \
  --cluster-type autopilot \
  --turbo-server "https://your-turbonomic-server.example.com" \
  --cluster-name "your-gke-autopilot-cluster-name" \
  --project-id "your-gcp-project-id"
```

---

## インストールの確認

### 1. Pod の状態確認

```bash
# Pod の一覧表示
kubectl get pods -n turbo

# 期待される出力:
# NAME                         READY   STATUS    RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Pod の詳細確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo
```

### 2. ログの確認

```bash
# リアルタイムログの表示
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo -f

# 最近のログを表示
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=100
```

**正常な起動ログの例:**

```
I0304 10:00:00.000000       1 kubeturbo.go:123] Starting Kubeturbo...
I0304 10:00:01.000000       1 kubeturbo.go:456] Successfully connected to Turbonomic server
I0304 10:00:02.000000       1 kubeturbo.go:789] Cluster discovery started
I0304 10:00:05.000000       1 kubeturbo.go:890] Successfully registered target: your-cluster-name
```

### 3. イベントの確認

```bash
# namespace のイベント確認
kubectl get events -n turbo --sort-by='.lastTimestamp'

# Pod のイベント確認
kubectl get events -n turbo --field-selector involvedObject.kind=Pod
```

### 4. Helm リリースの確認

```bash
# リリース情報の表示
helm list -n turbo

# リリースの詳細
helm status kubeturbo -n turbo

# 使用された values の確認
helm get values kubeturbo -n turbo
```

### 5. Service Account の確認

```bash
# Service Account の確認
kubectl get serviceaccount kubeturbo -n turbo -o yaml

# Workload Identity のアノテーション確認
kubectl get serviceaccount kubeturbo -n turbo -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
```

### 6. RBAC の確認

```bash
# ClusterRole の確認
kubectl get clusterrole | grep kubeturbo

# ClusterRoleBinding の確認
kubectl get clusterrolebinding | grep kubeturbo

# 権限の詳細確認
kubectl describe clusterrole kubeturbo
```

---

## トラブルシューティング

### Pod が起動しない

```bash
# Pod の状態を詳細に確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo

# イベントを確認
kubectl get events -n turbo --sort-by='.lastTimestamp'

# ログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
```

**よくある原因:**

1. **ImagePullBackOff**: イメージのプル権限がない
   ```bash
   # イメージプルシークレットの確認
   kubectl get secret -n turbo
   ```

2. **CrashLoopBackOff**: 設定エラーまたは接続エラー
   ```bash
   # ログで詳細を確認
   kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --previous
   ```

3. **Pending**: リソース不足
   ```bash
   # ノードのリソース確認
   kubectl top nodes
   kubectl describe nodes
   ```

### Turbonomic サーバーに接続できない

```bash
# Pod から接続テスト
kubectl exec -it -n turbo deployment/kubeturbo -- \
  curl -k -I https://your-turbonomic-server.example.com

# DNS 解決の確認
kubectl exec -it -n turbo deployment/kubeturbo -- \
  nslookup your-turbonomic-server.example.com
```

### Workload Identity が動作しない

```bash
# Service Account のアノテーション確認
kubectl get sa kubeturbo -n turbo -o yaml

# Pod から GCP 認証を確認
kubectl exec -it -n turbo deployment/kubeturbo -- \
  curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

### 認証エラー

```bash
# Secret の内容確認
kubectl get secret turbonomic-credentials -n turbo -o yaml

# Secret のデコード
kubectl get secret turbonomic-credentials -n turbo -o jsonpath='{.data.turboUsername}' | base64 -d
kubectl get secret turbonomic-credentials -n turbo -o jsonpath='{.data.turboPassword}' | base64 -d
```

---

## インストールのアンインストール

必要に応じて、Kubeturbo をアンインストールできます：

```bash
# Helm リリースの削除
helm uninstall kubeturbo -n turbo

# namespace の削除（必要な場合）
kubectl delete namespace turbo

# CRD の削除（必要な場合）
kubectl get crd | grep turbonomic | awk '{print $1}' | xargs kubectl delete crd
```

---

## 次のステップ

インストールが完了したら、以下のドキュメントを参照してください：

1. **[Turbonomic 接続設定](03-turbonomic-connection.md)** - Turbonomic UI での確認と設定
2. **[動作確認](04-verification.md)** - インストール後の動作確認
3. **[トラブルシューティング](05-troubleshooting.md)** - 問題が発生した場合の対処方法

---

## 参考コマンド集

### インストール情報の確認

```bash
# すべてのリソースを確認
kubectl get all -n turbo

# ConfigMap の確認
kubectl get configmap -n turbo

# Secret の確認
kubectl get secret -n turbo

# PersistentVolumeClaim の確認（使用している場合）
kubectl get pvc -n turbo
```

### ログとメトリクス

```bash
# ログのエクスポート
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo > kubeturbo.log

# リソース使用状況の確認
kubectl top pod -n turbo

# Pod のメトリクス詳細
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo | grep -A 5 "Limits\|Requests"
```

### デバッグ

```bash
# Pod 内でシェルを起動
kubectl exec -it -n turbo deployment/kubeturbo -- /bin/sh

# 一時的なデバッグ Pod を起動
kubectl run -it --rm debug --image=busybox --restart=Never -n turbo -- sh

# ネットワーク接続のテスト
kubectl run -it --rm nettest --image=nicolaka/netshoot --restart=Never -n turbo -- bash
```

---

## ベストプラクティス

### 1. values ファイルのバージョン管理

```bash
# Git で values ファイルを管理
git add values/my-kubeturbo-values.yaml
git commit -m "Add Kubeturbo configuration for production cluster"
```

### 2. 複数環境の管理

```bash
# 環境ごとに values ファイルを作成
values/
  ├── values-dev.yaml
  ├── values-staging.yaml
  └── values-production.yaml

# 環境に応じてインストール
helm install kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-production.yaml
```

### 3. Helm のドライラン

```bash
# インストール前にドライランで確認
helm install kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-standard-gke.yaml \
  --dry-run --debug
```

### 4. 定期的なバックアップ

```bash
# Helm values のバックアップ
helm get values kubeturbo -n turbo > backup-values-$(date +%Y%m%d).yaml

# Secret のバックアップ
kubectl get secret turbonomic-credentials -n turbo -o yaml > backup-secret-$(date +%Y%m%d).yaml
```

---

## 参考リンク

- [Helm 公式ドキュメント](https://helm.sh/docs/)
- [Kubeturbo GitHub](https://github.com/turbonomic/kubeturbo)
- [Turbonomic ドキュメント](https://www.ibm.com/docs/en/tarm)
- [GKE ドキュメント](https://cloud.google.com/kubernetes-engine/docs)
# 事前準備

Kubeturbo を GKE にデプロイする前に、必要な準備作業を行います。

## 目次

- [必要なツール](#必要なツール)
- [GCP プロジェクトの準備](#gcp-プロジェクトの準備)
- [GKE クラスタの準備](#gke-クラスタの準備)
- [IAM 権限の設定](#iam-権限の設定)
- [Workload Identity の設定](#workload-identity-の設定)
- [Turbonomic サーバーの準備](#turbonomic-サーバーの準備)

---

## 必要なツール

以下のツールがインストールされていることを確認してください：

### 1. Google Cloud SDK (gcloud)

```bash
# インストール確認
gcloud version

# インストールされていない場合
# https://cloud.google.com/sdk/docs/install
```

### 2. kubectl

```bash
# インストール確認
kubectl version --client

# gcloud 経由でインストール
gcloud components install kubectl
```

### 3. Helm (v3.x)

```bash
# インストール確認
helm version

# インストール（macOS の場合）
brew install helm

# インストール（Linux の場合）
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## GCP プロジェクトの準備

### 1. GCP プロジェクトの選択

```bash
# プロジェクト一覧の確認
gcloud projects list

# プロジェクトの設定
export PROJECT_ID="your-project-id"
gcloud config set project ${PROJECT_ID}
```

### 2. 必要な API の有効化

```bash
# Kubernetes Engine API
gcloud services enable container.googleapis.com

# IAM API（Workload Identity 使用時）
gcloud services enable iam.googleapis.com

# Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com

# Compute Engine API
gcloud services enable compute.googleapis.com
```

### 3. デフォルトのリージョン/ゾーンの設定

```bash
# リージョンの設定（例: 東京リージョン）
gcloud config set compute/region asia-northeast1

# ゾーンの設定
gcloud config set compute/zone asia-northeast1-a
```

---

## GKE クラスタの準備

### Standard GKE クラスタの作成

既存のクラスタがない場合、以下のコマンドで作成できます：

```bash
# 環境変数の設定
export CLUSTER_NAME="kubeturbo-cluster"
export REGION="asia-northeast1"
export ZONE="asia-northeast1-a"

# Standard クラスタの作成
gcloud container clusters create ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --num-nodes=3 \
  --machine-type=e2-standard-4 \
  --disk-size=100 \
  --disk-type=pd-standard \
  --enable-autoscaling \
  --min-nodes=3 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --enable-stackdriver-kubernetes \
  --addons=HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver
```

### Autopilot GKE クラスタの作成

```bash
# Autopilot クラスタの作成
gcloud container clusters create-auto ${CLUSTER_NAME} \
  --region=${REGION} \
  --release-channel=regular
```

### 既存クラスタへの接続

```bash
# Standard クラスタの場合
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --zone=${ZONE}

# Autopilot クラスタの場合
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --region=${REGION}

# 接続確認
kubectl cluster-info
kubectl get nodes
```

---

## IAM 権限の設定

### 1. 必要な権限の確認

Kubeturbo をデプロイするユーザーには、以下の権限が必要です：

- `container.clusters.get`
- `container.clusters.update`
- `iam.serviceAccounts.create`（Workload Identity 使用時）
- `iam.serviceAccounts.getIamPolicy`（Workload Identity 使用時）
- `iam.serviceAccounts.setIamPolicy`（Workload Identity 使用時）

### 2. カスタムロールの作成（オプション）

```bash
# カスタムロールの作成
gcloud iam roles create kubeturboDeployer \
  --project=${PROJECT_ID} \
  --title="Kubeturbo Deployer" \
  --description="Role for deploying Kubeturbo" \
  --permissions=container.clusters.get,container.clusters.update,iam.serviceAccounts.create,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy \
  --stage=GA
```

### 3. ユーザーへの権限付与

```bash
# 現在のユーザーを確認
gcloud config get-value account

# 権限の付与
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="user:your-email@example.com" \
  --role="roles/container.admin"
```

---

## Workload Identity の設定

Workload Identity は、GKE の Pod が GCP サービスに安全にアクセスするための推奨方法です。

### 1. Workload Identity の有効化確認

```bash
# クラスタの Workload Identity 設定を確認
# Standard クラスタの場合
gcloud container clusters describe ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --format="value(workloadIdentityConfig.workloadPool)"

# Autopilot クラスタの場合
gcloud container clusters describe ${CLUSTER_NAME} \
  --region=${REGION} \
  --format="value(workloadIdentityConfig.workloadPool)"

# 出力例: your-project-id.svc.id.goog
```

既存のクラスタで Workload Identity が無効な場合：

```bash
# Standard クラスタの場合
gcloud container clusters update ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --workload-pool=${PROJECT_ID}.svc.id.goog

# ノードプールの更新も必要
gcloud container node-pools update default-pool \
  --cluster=${CLUSTER_NAME} \
  --zone=${ZONE} \
  --workload-metadata=GKE_METADATA
```

### 2. GCP サービスアカウントの作成

```bash
# サービスアカウント名の設定
export GSA_NAME="kubeturbo"
export GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# GCP サービスアカウントの作成
gcloud iam service-accounts create ${GSA_NAME} \
  --display-name="Kubeturbo Service Account" \
  --description="Service account for Kubeturbo to access GCP resources"
```

### 3. GCP サービスアカウントへの権限付与

```bash
# Kubernetes Engine Viewer 権限の付与
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/container.viewer"

# Monitoring Metric Writer 権限の付与（メトリクス送信用）
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/monitoring.metricWriter"

# Logging Writer 権限の付与（ログ送信用）
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/logging.logWriter"
```

### 4. Kubernetes Service Account との紐付け

```bash
# Kubernetes namespace の作成
kubectl create namespace turbo

# Kubernetes Service Account の作成
kubectl create serviceaccount kubeturbo -n turbo

# Workload Identity の紐付け
gcloud iam service-accounts add-iam-policy-binding ${GSA_EMAIL} \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[turbo/kubeturbo]"

# Kubernetes Service Account にアノテーションを追加
kubectl annotate serviceaccount kubeturbo \
  -n turbo \
  iam.gke.io/gcp-service-account=${GSA_EMAIL}
```

### 5. Workload Identity の動作確認

```bash
# テスト Pod の作成
kubectl run -it --rm --restart=Never \
  --image=google/cloud-sdk:slim \
  -n turbo \
  workload-identity-test \
  -- gcloud auth list

# 出力に kubeturbo@PROJECT_ID.iam.gserviceaccount.com が表示されれば成功
```

---

## Turbonomic サーバーの準備

### 1. Turbonomic サーバー情報の確認

以下の情報を準備してください：

- **Turbonomic サーバー URL**: `https://turbonomic.example.com`
- **管理者ユーザー名**: 通常は `administrator`
- **管理者パスワード**: Turbonomic 管理者から取得

### 2. ネットワーク接続の確認

GKE クラスタから Turbonomic サーバーへの接続を確認します：

```bash
# テスト Pod から接続確認
kubectl run -it --rm --restart=Never \
  --image=curlimages/curl:latest \
  curl-test \
  -- curl -k -I https://turbonomic.example.com

# 200 OK または 302 Found が返れば接続可能
```

### 3. ファイアウォールルールの確認

Turbonomic サーバーがオンプレミスにある場合、以下を確認してください：

- GKE クラスタの Egress トラフィックが許可されているか
- Turbonomic サーバーのポート（通常 443）が開いているか
- プロキシ経由の接続が必要な場合、プロキシ設定を準備

### 4. Kubernetes Secret の作成

Turbonomic の認証情報を Secret として作成します：

```bash
# Secret の作成
kubectl create secret generic turbonomic-credentials \
  -n turbo \
  --from-literal=turboUsername=administrator \
  --from-literal=turboPassword='your-password-here'

# Secret の確認
kubectl get secret turbonomic-credentials -n turbo -o yaml
```

**セキュリティのベストプラクティス:**

- パスワードはコマンド履歴に残らないよう、ファイルから読み込むことを推奨：

```bash
# パスワードをファイルに保存（一時的）
echo -n 'your-password-here' > /tmp/turbo-password.txt

# ファイルから Secret を作成
kubectl create secret generic turbonomic-credentials \
  -n turbo \
  --from-literal=turboUsername=administrator \
  --from-file=turboPassword=/tmp/turbo-password.txt

# ファイルを削除
rm /tmp/turbo-password.txt
```

---

## チェックリスト

インストール前に、以下の項目を確認してください：

- [ ] gcloud、kubectl、helm がインストールされている
- [ ] GCP プロジェクトが選択されている
- [ ] 必要な GCP API が有効化されている
- [ ] GKE クラスタが作成され、接続できる
- [ ] Workload Identity が有効化されている（推奨）
- [ ] GCP サービスアカウントが作成され、権限が付与されている
- [ ] Kubernetes Service Account が作成され、Workload Identity が紐付けられている
- [ ] Turbonomic サーバーへの接続が確認できる
- [ ] Turbonomic の認証情報が Kubernetes Secret として作成されている

---

## 次のステップ

事前準備が完了したら、[インストール手順](02-installation.md) に進んでください。

---

## トラブルシューティング

### Workload Identity が動作しない

```bash
# クラスタの設定を確認
gcloud container clusters describe ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --format="value(workloadIdentityConfig.workloadPool)"

# ノードプールの設定を確認
gcloud container node-pools describe default-pool \
  --cluster=${CLUSTER_NAME} \
  --zone=${ZONE} \
  --format="value(config.workloadMetadataConfig.mode)"

# GKE_METADATA が表示されない場合は更新が必要
```

### API が有効化されない

```bash
# API の有効化状態を確認
gcloud services list --enabled --filter="name:container.googleapis.com"

# 強制的に有効化
gcloud services enable container.googleapis.com --project=${PROJECT_ID}
```

### kubectl が接続できない

```bash
# 認証情報の更新
gcloud container clusters get-credentials ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --project=${PROJECT_ID}

# コンテキストの確認
kubectl config current-context

# 接続テスト
kubectl get nodes
```

---

## 参考リンク

- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [GKE クラスタの作成](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-cluster)
- [GKE Autopilot の概要](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
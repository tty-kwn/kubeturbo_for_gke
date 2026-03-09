# トラブルシューティング

Kubeturbo の運用中に発生する可能性のある問題と、その解決方法を説明します。

## 目次

- [一般的な問題](#一般的な問題)
- [インストール時の問題](#インストール時の問題)
- [接続の問題](#接続の問題)
- [メトリクス収集の問題](#メトリクス収集の問題)
- [パフォーマンスの問題](#パフォーマンスの問題)
- [GKE 固有の問題](#gke-固有の問題)
- [ログの分析](#ログの分析)
- [サポートへの問い合わせ](#サポートへの問い合わせ)

---

## 一般的な問題

### Pod が起動しない

#### 症状

```bash
kubectl get pods -n turbo
# NAME                         READY   STATUS             RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   5          5m
```

#### 原因と解決方法

**1. ImagePullBackOff / ErrImagePull**

```bash
# 問題の確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo | grep -A 5 "Events:"

# 原因: イメージレジストリへのアクセス権限がない
# 解決方法:

# イメージが存在するか確認
docker pull icr.io/cpopen/turbonomic/kubeturbo:8.14.3

# プライベートレジストリの場合、ImagePullSecret を作成
kubectl create secret docker-registry icr-secret \
  --docker-server=icr.io \
  --docker-username=iamapikey \
  --docker-password=<YOUR_API_KEY> \
  -n turbo

# values.yaml に追加
imagePullSecrets:
  - name: icr-secret
```

**2. CrashLoopBackOff**

```bash
# ログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --previous

# よくある原因:
# - Turbonomic サーバーへの接続失敗
# - 認証情報の誤り
# - 設定ファイルのエラー

# 解決方法: ログのエラーメッセージに基づいて対処
```

**3. Pending 状態**

```bash
# 問題の確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo

# 原因 1: リソース不足
# ノードのリソースを確認
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# 解決方法: リソース要求を減らすか、ノードを追加
resources:
  requests:
    memory: 512Mi  # 1Gi から削減
    cpu: 250m      # 500m から削減

# 原因 2: ノードセレクタの不一致（Standard GKE）
# 解決方法: nodeSelector を削除または修正
nodeSelector: {}

# 原因 3: Taint/Toleration の問題
# ノードの Taint を確認
kubectl describe nodes | grep Taints

# 解決方法: 適切な Toleration を追加
tolerations:
  - key: "node-role"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"
```

### Pod が頻繁に再起動する

#### 症状

```bash
kubectl get pods -n turbo
# NAME                         READY   STATUS    RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   1/1     Running   15         30m
```

#### 原因と解決方法

**1. メモリ不足（OOMKilled）**

```bash
# 問題の確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "OOMKilled"

# 解決方法: メモリ制限を増やす
resources:
  limits:
    memory: 2Gi  # 1Gi から増加
  requests:
    memory: 1Gi  # 512Mi から増加
```

**2. Liveness Probe の失敗**

```bash
# ログで確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "liveness"

# 解決方法: Probe の設定を調整
livenessProbe:
  initialDelaySeconds: 60  # 30 から増加
  periodSeconds: 30        # 10 から増加
  timeoutSeconds: 10       # 5 から増加
```

**3. アプリケーションエラー**

```bash
# ログで詳細を確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=200

# よくあるエラー:
# - "connection refused": Turbonomic サーバーへの接続失敗
# - "authentication failed": 認証情報の誤り
# - "timeout": ネットワークの問題
```

---

## インストール時の問題

### Helm インストールが失敗する

#### 症状

```bash
helm install kubeturbo turbonomic/kubeturbo -n turbo -f values.yaml
# Error: INSTALLATION FAILED: ...
```

#### 原因と解決方法

**1. namespace が存在しない**

```bash
# エラー: namespaces "turbo" not found

# 解決方法: namespace を作成
kubectl create namespace turbo

# または --create-namespace オプションを使用
helm install kubeturbo turbonomic/kubeturbo \
  -n turbo \
  --create-namespace \
  -f values.yaml
```

**2. values ファイルの構文エラー**

```bash
# 解決方法: YAML の構文を確認
yamllint values.yaml

# または Helm のドライランで確認
helm install kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values.yaml \
  --dry-run --debug
```

**3. 既存のリソースとの競合**

```bash
# エラー: resource already exists

# 解決方法: 既存のリソースを削除
kubectl delete deployment kubeturbo -n turbo
kubectl delete serviceaccount kubeturbo -n turbo

# または Helm でアンインストール
helm uninstall kubeturbo -n turbo
```

### Secret が作成されない

#### 症状

```bash
kubectl get secret turbonomic-credentials -n turbo
# Error from server (NotFound): secrets "turbonomic-credentials" not found
```

#### 解決方法

```bash
# Secret を手動で作成
kubectl create secret generic turbonomic-credentials \
  -n turbo \
  --from-literal=turboUsername=administrator \
  --from-literal=turboPassword='your-password-here'

# Secret の確認
kubectl get secret turbonomic-credentials -n turbo -o yaml
```

---

## 接続の問題

### Turbonomic サーバーに接続できない

#### 症状

```bash
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
# Error: Failed to connect to Turbonomic server
# Error: connection refused
# Error: timeout
```

#### 診断手順

**1. ネットワーク接続の確認**

```bash
# Pod から接続テスト
kubectl exec -n turbo deployment/kubeturbo -- \
  curl -k -I https://your-turbonomic-server.example.com

# 期待される出力: HTTP/1.1 200 OK または 302 Found

# DNS 解決の確認
kubectl exec -n turbo deployment/kubeturbo -- \
  nslookup your-turbonomic-server.example.com

# ポート接続の確認
kubectl exec -n turbo deployment/kubeturbo -- \
  nc -zv your-turbonomic-server.example.com 443
```

**2. ファイアウォールの確認**

```bash
# GKE クラスタの Egress ルールを確認
gcloud compute firewall-rules list --filter="direction=EGRESS"

# 必要に応じて Egress ルールを追加
gcloud compute firewall-rules create allow-turbonomic-egress \
  --direction=EGRESS \
  --action=ALLOW \
  --rules=tcp:443 \
  --destination-ranges=<TURBONOMIC_SERVER_IP>/32
```

**3. プロキシ設定の確認**

プロキシ経由で接続する場合：

```yaml
# values.yaml
serverMeta:
  turboServer: "https://your-turbonomic-server.example.com"
  proxy: "http://proxy.example.com:8080"

# または環境変数で設定
env:
  - name: HTTP_PROXY
    value: "http://proxy.example.com:8080"
  - name: HTTPS_PROXY
    value: "http://proxy.example.com:8080"
  - name: NO_PROXY
    value: "localhost,127.0.0.1,.svc,.cluster.local"
```

### 認証エラー

#### 症状

```bash
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
# Error: Authentication failed
# Error: Invalid credentials
# Error: 401 Unauthorized
```

#### 解決方法

**1. 認証情報の確認**

```bash
# Secret の内容を確認
kubectl get secret turbonomic-credentials -n turbo -o yaml

# ユーザー名とパスワードをデコード
kubectl get secret turbonomic-credentials -n turbo \
  -o jsonpath='{.data.turboUsername}' | base64 -d
echo ""
kubectl get secret turbonomic-credentials -n turbo \
  -o jsonpath='{.data.turboPassword}' | base64 -d
echo ""

# Turbonomic UI で認証情報を確認
# 正しい認証情報で Secret を再作成
kubectl delete secret turbonomic-credentials -n turbo
kubectl create secret generic turbonomic-credentials \
  -n turbo \
  --from-literal=turboUsername=administrator \
  --from-literal=turboPassword='correct-password'

# Pod を再起動
kubectl rollout restart deployment kubeturbo -n turbo
```

**2. ユーザー権限の確認**

Turbonomic UI で確認：
- ユーザーが有効になっているか
- 必要な権限（Observer 以上）があるか
- アカウントがロックされていないか

---

## メトリクス収集の問題

### メトリクスが収集されない

#### 症状

Turbonomic UI でメトリクスが表示されない、または古いデータのまま更新されない。

#### 診断手順

**1. Metrics Server の確認**

```bash
# Metrics Server が動作しているか確認
kubectl get deployment metrics-server -n kube-system

# Metrics Server のログを確認
kubectl logs -n kube-system -l k8s-app=metrics-server

# メトリクスが取得できるか確認
kubectl top nodes
kubectl top pods -A
```

**2. RBAC 権限の確認**

```bash
# 必要な権限があるか確認
kubectl auth can-i get nodes --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get pods --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get nodes/metrics --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get pods/metrics --as=system:serviceaccount:turbo:kubeturbo

# すべて "yes" が返ることを確認
```

**3. Kubelet への接続確認**

```bash
# Kubeturbo のログで Kubelet 接続を確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i kubelet

# Kubelet のポート設定を確認
# values.yaml
args:
  kubelethttps: true
  kubeletport: 10250  # デフォルト
```

### 一部のメトリクスのみ収集されない

#### 原因と解決方法

**1. ネットワークメトリクス**

```bash
# CNI プラグインの確認
kubectl get pods -n kube-system | grep -E "calico|cilium|flannel"

# ネットワークポリシーの確認
kubectl get networkpolicies -A
```

**2. ストレージメトリクス**

```bash
# CSI ドライバーの確認
kubectl get csidrivers

# PersistentVolume の確認
kubectl get pv
kubectl get pvc -A
```

---

## パフォーマンスの問題

### Kubeturbo の CPU/メモリ使用量が高い

#### 症状

```bash
kubectl top pod -n turbo
# NAME                         CPU(cores)   MEMORY(bytes)
# kubeturbo-xxxxxxxxxx-xxxxx   1000m        3Gi
```

#### 原因と解決方法

**1. 大規模クラスタでの高負荷**

```bash
# クラスタのサイズを確認
kubectl get nodes | wc -l
kubectl get pods -A | wc -l

# 解決方法: リソース制限を増やす
resources:
  limits:
    memory: 4Gi  # 2Gi から増加
    cpu: 2000m   # 1000m から増加
  requests:
    memory: 2Gi
    cpu: 1000m
```

**2. 検出間隔が短すぎる**

```yaml
# 解決方法: 検出間隔を長くする
args:
  discoveryIntervalSec: 900  # 600 から 900 に増加（15分）
```

**3. ログレベルが高すぎる**

```yaml
# 解決方法: ログレベルを下げる
args:
  logginglevel: 1  # 2（Trace）から 1（Debug）に変更
  # または 0（Info）に変更
```

### Kubernetes API への負荷が高い

#### 症状

```bash
# API サーバーのログでエラーが頻発
kubectl logs -n kube-system -l component=kube-apiserver | grep -i "rate limit"
```

#### 解決方法

```yaml
# Kubeturbo のレート制限を設定
args:
  # API 呼び出しの間隔を調整
  discoveryIntervalSec: 900  # 検出間隔を長くする
  
# または、複数の Kubeturbo インスタンスを使用しない
replicaCount: 1  # 2 以上にしない
```

---

## GKE 固有の問題

### Autopilot での制約エラー

#### 症状

```bash
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo
# Error: Pod Security Policy violation
# Error: Forbidden: violates PodSecurity
```

#### 解決方法

**1. セキュリティコンテキストの修正**

```yaml
# values-autopilot-gke.yaml を使用
securityContext:
  runAsNonRoot: true
  runAsUser: 2000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  seccompProfile:
    type: RuntimeDefault
```

**2. リソース要求の修正**

```yaml
# Autopilot では requests と limits を同じ値に
resources:
  limits:
    memory: 2Gi
    cpu: 1000m
  requests:
    memory: 2Gi  # limits と同じ
    cpu: 1000m   # limits と同じ
```

### Workload Identity が動作しない

#### 症状

```bash
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
# Error: Failed to get GCP credentials
# Error: Metadata server unavailable
```

#### 診断手順

**1. Workload Identity の設定確認**

```bash
# クラスタの Workload Identity 設定
gcloud container clusters describe ${CLUSTER_NAME} \
  --zone=${ZONE} \
  --format="value(workloadIdentityConfig.workloadPool)"

# 出力: your-project-id.svc.id.goog

# Service Account のアノテーション確認
kubectl get sa kubeturbo -n turbo -o yaml | grep -A 2 annotations

# 出力に以下が含まれることを確認:
# iam.gke.io/gcp-service-account: kubeturbo@PROJECT_ID.iam.gserviceaccount.com
```

**2. IAM バインディングの確認**

```bash
# GCP サービスアカウントの確認
gcloud iam service-accounts describe kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com

# IAM ポリシーバインディングの確認
gcloud iam service-accounts get-iam-policy \
  kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com

# Workload Identity User ロールがあることを確認
```

**3. 修正方法**

```bash
# IAM バインディングを再設定
gcloud iam service-accounts add-iam-policy-binding \
  kubeturbo@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[turbo/kubeturbo]"

# Pod を再起動
kubectl rollout restart deployment kubeturbo -n turbo
```

### GKE ノードプールの自動スケーリングとの競合

#### 症状

Turbonomic の推奨と GKE の Cluster Autoscaler が競合する。

#### 解決方法

```yaml
# Turbonomic のノードアクションを推奨のみに設定
# Turbonomic UI で設定:
# Settings → Policies → Automation Policies

# Node Provision: Recommend（自動実行しない）
# Node Suspend: Recommend（自動実行しない）

# GKE の Cluster Autoscaler に任せる
```

---

## ログの分析

### ログレベルの変更

```yaml
# values.yaml
args:
  logginglevel: 2  # 0=Info, 1=Debug, 2=Trace
```

### 有用なログパターン

```bash
# 接続成功のログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "connected\|registered"

# エラーログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "error\|failed\|fatal"

# 警告ログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "warn"

# 検出サイクルのログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "discovery"

# メトリクス収集のログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "metric"
```

### ログのエクスポート

```bash
# ログをファイルに保存
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo > kubeturbo-$(date +%Y%m%d-%H%M%S).log

# 過去のログも含めて保存
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --previous > kubeturbo-previous-$(date +%Y%m%d-%H%M%S).log

# すべての Pod のログを保存
for pod in $(kubectl get pods -n turbo -l app.kubernetes.io/name=kubeturbo -o name); do
  kubectl logs -n turbo $pod > ${pod}-$(date +%Y%m%d-%H%M%S).log
done
```

---

## サポートへの問い合わせ

### 必要な情報の収集

サポートに問い合わせる前に、以下の情報を収集してください：

```bash
# 1. 環境情報
kubectl version
helm version
gcloud version

# 2. クラスタ情報
kubectl cluster-info
kubectl get nodes -o wide

# 3. Kubeturbo の情報
kubectl get all -n turbo
kubectl describe deployment kubeturbo -n turbo
kubectl get events -n turbo --sort-by='.lastTimestamp'

# 4. ログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=500 > kubeturbo.log

# 5. 設定情報
helm get values kubeturbo -n turbo > kubeturbo-values.yaml

# 6. リソース使用状況
kubectl top nodes
kubectl top pods -n turbo
```

### サポートバンドルの作成

```bash
#!/bin/bash
# create-support-bundle.sh

BUNDLE_DIR="kubeturbo-support-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BUNDLE_DIR

# 環境情報
kubectl version > $BUNDLE_DIR/kubectl-version.txt
helm version > $BUNDLE_DIR/helm-version.txt
gcloud version > $BUNDLE_DIR/gcloud-version.txt

# クラスタ情報
kubectl cluster-info > $BUNDLE_DIR/cluster-info.txt
kubectl get nodes -o wide > $BUNDLE_DIR/nodes.txt

# Kubeturbo 情報
kubectl get all -n turbo -o yaml > $BUNDLE_DIR/kubeturbo-resources.yaml
kubectl describe deployment kubeturbo -n turbo > $BUNDLE_DIR/kubeturbo-deployment.txt
kubectl get events -n turbo --sort-by='.lastTimestamp' > $BUNDLE_DIR/events.txt

# ログ
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=1000 > $BUNDLE_DIR/kubeturbo.log

# 設定
helm get values kubeturbo -n turbo > $BUNDLE_DIR/values.yaml

# アーカイブ
tar czf $BUNDLE_DIR.tar.gz $BUNDLE_DIR
echo "Support bundle created: $BUNDLE_DIR.tar.gz"
```

---

## よくある質問（FAQ）

### Q: Kubeturbo を複数のクラスタにデプロイできますか？

A: はい、各クラスタに個別にデプロイできます。各クラスタは Turbonomic UI で別々のターゲットとして表示されます。

### Q: Kubeturbo のアップグレード中にダウンタイムはありますか？

A: Kubeturbo 自体のダウンタイムはありますが、監視対象のワークロードには影響しません。アップグレード中はメトリクス収集が一時的に停止します。

### Q: Kubeturbo を削除するとクラスタに影響はありますか？

A: いいえ、Kubeturbo は監視のみを行うため、削除してもクラスタやワークロードには影響しません。

### Q: Autopilot と Standard でどちらを使うべきですか？

A: 要件によります。Autopilot は管理が簡単ですが、一部の機能に制限があります。Standard はより柔軟ですが、管理の負担が大きくなります。

---

## 参考リンク

- [Kubeturbo GitHub Issues](https://github.com/turbonomic/kubeturbo/issues)
- [Turbonomic サポート](https://www.ibm.com/mysupport/)
- [GKE トラブルシューティング](https://cloud.google.com/kubernetes-engine/docs/troubleshooting)
- [Kubernetes デバッグ](https://kubernetes.io/docs/tasks/debug/)
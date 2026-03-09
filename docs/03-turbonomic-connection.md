# Turbonomic 接続設定

Kubeturbo のインストール後、Turbonomic UI でクラスタの接続状態を確認し、必要な設定を行います。

## 目次

- [Turbonomic UI へのアクセス](#turbonomic-ui-へのアクセス)
- [ターゲットの確認](#ターゲットの確認)
- [接続状態の確認](#接続状態の確認)
- [ターゲット設定のカスタマイズ](#ターゲット設定のカスタマイズ)
- [ポリシーの設定](#ポリシーの設定)
- [アクションの設定](#アクションの設定)
- [トラブルシューティング](#トラブルシューティング)

---

## Turbonomic UI へのアクセス

### 1. Turbonomic にログイン

```
URL: https://your-turbonomic-server.example.com
ユーザー名: administrator（または指定されたユーザー）
パスワード: （管理者から提供されたパスワード）
```

### 2. ダッシュボードの確認

ログイン後、メインダッシュボードが表示されます。

---

## ターゲットの確認

### 1. ターゲット一覧の表示

1. 左側のメニューから **Settings** をクリック
2. **Target Configuration** を選択
3. ターゲット一覧が表示されます

### 2. Kubernetes ターゲットの確認

GKE クラスタが以下のように表示されているはずです：

```
Name: your-gke-cluster-name
Type: Kubernetes
Status: Validated (緑色のチェックマーク)
```

**ステータスの意味:**

- **Validated** (緑): 正常に接続されている
- **Validation Failed** (赤): 接続に問題がある
- **Validating** (黄): 検証中

### 3. ターゲットの詳細確認

ターゲット名をクリックすると、詳細情報が表示されます：

- **Connection Status**: 接続状態
- **Last Discovery**: 最後の検出時刻
- **Discovered Entities**: 検出されたエンティティ数
  - Nodes
  - Namespaces
  - Pods
  - Containers
  - Services
  - Volumes

---

## 接続状態の確認

### 正常な接続の確認項目

#### 1. ターゲットステータス

```
Status: Validated
Last Validated: 2026-03-04 10:00:00
```

#### 2. 検出されたエンティティ

以下のエンティティが検出されているか確認：

```
✓ Cluster: 1
✓ Nodes: X個（クラスタのノード数）
✓ Namespaces: Y個
✓ Pods: Z個
✓ Containers: W個
```

#### 3. メトリクスの収集

- CPU 使用率
- メモリ使用率
- ネットワークスループット
- ストレージ使用率

これらのメトリクスがリアルタイムで更新されていることを確認します。

### Kubernetes クラスタの表示

1. 左側のメニューから **Search** をクリック
2. **Kubernetes** カテゴリを選択
3. クラスタ名をクリック

クラスタのトポロジービューが表示され、以下が確認できます：

- ノードの配置
- Pod の分散状況
- リソース使用状況
- 推奨アクション

---

## ターゲット設定のカスタマイズ

### 1. ターゲット設定の編集

1. **Settings** → **Target Configuration** に移動
2. Kubernetes ターゲットを選択
3. **Edit** ボタンをクリック

### 2. 基本設定

#### ターゲット名の変更

```
Target Name: gke-production-cluster
Description: Production GKE cluster in asia-northeast1
```

#### 検出間隔の設定

```
Discovery Interval: 10 minutes（デフォルト）
```

**推奨値:**
- 本番環境: 10-15 分
- 開発環境: 5-10 分
- 大規模クラスタ: 15-20 分

### 3. 高度な設定

#### メトリクス収集の設定

```yaml
# Kubeturbo の args 設定（values.yaml）
args:
  logginglevel: 2
  kubelethttps: true
  kubeletport: 10250
  
  # メトリクス収集間隔（秒）
  # デフォルト: 600（10分）
  discoveryIntervalSec: 600
```

#### リソース制限の設定

```yaml
# 監視対象の namespace を制限
targetConfig:
  # 除外する namespace
  excludedNamespaces:
    - kube-system
    - kube-public
    - kube-node-lease
  
  # 監視する namespace のみ指定
  # includedNamespaces:
  #   - production
  #   - staging
```

---

## ポリシーの設定

Turbonomic のポリシーを設定して、自動化の動作を制御します。

### 1. 自動化ポリシーの設定

1. **Settings** → **Policies** に移動
2. **Automation Policies** を選択
3. **New Automation Policy** をクリック

### 2. Kubernetes 用ポリシーの作成

#### Pod のスケーリングポリシー

```
Policy Name: GKE Pod Scaling Policy
Scope: Kubernetes Cluster → your-gke-cluster-name
Action: Scale
Mode: Recommend（推奨のみ）または Automatic（自動実行）
```

**アクションタイプ:**

- **Recommend**: 推奨のみ表示、手動で実行
- **Automatic**: 自動的に実行
- **Manual Approval**: 承認後に実行

#### リソース制限の調整ポリシー

```
Policy Name: GKE Resource Limit Policy
Scope: Kubernetes Cluster → your-gke-cluster-name
Action: Resize
Mode: Recommend
```

### 3. ポリシーの優先順位

複数のポリシーがある場合、優先順位を設定：

```
1. Critical Workloads Policy（優先度: 高）
2. Production Workloads Policy（優先度: 中）
3. Development Workloads Policy（優先度: 低）
```

---

## アクションの設定

### 1. アクションの種類

Turbonomic が提案するアクション：

#### Pod レベル

- **Scale**: Pod のレプリカ数を増減
- **Move**: Pod を別のノードに移動
- **Resize**: Pod のリソース要求/制限を調整

#### ノードレベル

- **Provision**: 新しいノードを追加
- **Suspend**: 未使用のノードを削除
- **Resize**: ノードのサイズを変更

#### コンテナレベル

- **Resize**: CPU/メモリの要求/制限を調整

### 2. アクションの承認設定

#### 手動承認が必要なアクション

```
Settings → Policies → Action Approval

承認が必要なアクション:
☑ Node Provision
☑ Node Suspend
☑ Pod Move（本番環境）
☐ Pod Resize（開発環境）
```

#### 自動実行するアクション

```
自動実行するアクション:
☑ Container Resize（開発環境）
☑ Pod Scale（HPA が設定されていない場合）
☐ Node Provision（コスト影響大）
```

### 3. アクションの実行

#### 推奨アクションの確認

1. ダッシュボードの **Pending Actions** を確認
2. アクションをクリックして詳細を表示
3. **Show Details** で影響を確認

#### アクションの実行

```
1. アクションを選択
2. "Execute" ボタンをクリック
3. 確認ダイアログで "Confirm" をクリック
```

#### アクションの履歴確認

```
Settings → Action History

フィルタ:
- Time Range: Last 24 hours
- Action Type: All
- Status: Succeeded / Failed
```

---

## GKE 固有の設定

### 1. GKE Autopilot の考慮事項

Autopilot クラスタでは、以下のアクションが制限されます：

```
制限されるアクション:
✗ Node Provision（Google が自動管理）
✗ Node Suspend（Google が自動管理）
✗ Node Resize（Google が自動管理）

利用可能なアクション:
✓ Pod Scale
✓ Pod Move
✓ Container Resize
```

### 2. GKE Standard の最適化

Standard クラスタでは、ノードプールの自動スケーリングと連携：

```yaml
# GKE クラスタの設定
Cluster Autoscaler: Enabled
Min Nodes: 3
Max Nodes: 10

# Turbonomic の設定
Node Provision: Recommend（手動承認）
Node Suspend: Recommend（手動承認）
```

### 3. Workload Identity との統合

Turbonomic が GCP リソースを認識するための設定：

```
Settings → Target Configuration → Kubernetes Target

Advanced Settings:
☑ Enable Cloud Provider Integration
Cloud Provider: Google Cloud Platform
Service Account: kubeturbo@PROJECT_ID.iam.gserviceaccount.com
```

---

## モニタリングとアラート

### 1. ダッシュボードのカスタマイズ

```
Dashboard → Customize

追加するウィジェット:
- Cluster Health
- Resource Utilization
- Pending Actions
- Cost Optimization Opportunities
```

### 2. アラートの設定

```
Settings → Notifications

アラート条件:
- Cluster CPU > 80%
- Cluster Memory > 85%
- Pod Pending > 5 minutes
- Node Not Ready
```

### 3. レポートの設定

```
Reports → Schedule Report

レポートタイプ:
- Daily Cluster Summary
- Weekly Cost Optimization
- Monthly Capacity Planning
```

---

## トラブルシューティング

### ターゲットが Validated にならない

#### 1. 接続の確認

```bash
# Kubeturbo のログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i error

# Turbonomic サーバーへの接続テスト
kubectl exec -n turbo deployment/kubeturbo -- \
  curl -k -I https://your-turbonomic-server.example.com
```

#### 2. 認証情報の確認

```bash
# Secret の確認
kubectl get secret turbonomic-credentials -n turbo -o yaml

# ユーザー名とパスワードの確認
kubectl get secret turbonomic-credentials -n turbo \
  -o jsonpath='{.data.turboUsername}' | base64 -d
```

#### 3. ネットワークの確認

```bash
# DNS 解決の確認
kubectl exec -n turbo deployment/kubeturbo -- \
  nslookup your-turbonomic-server.example.com

# ファイアウォールの確認
kubectl exec -n turbo deployment/kubeturbo -- \
  nc -zv your-turbonomic-server.example.com 443
```

### メトリクスが収集されない

#### 1. Kubelet への接続確認

```bash
# Kubelet メトリクスの確認
kubectl top nodes
kubectl top pods -A

# Kubeturbo のログで Kubelet 接続を確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i kubelet
```

#### 2. RBAC 権限の確認

```bash
# ClusterRole の確認
kubectl get clusterrole kubeturbo -o yaml

# 必要な権限があるか確認
kubectl auth can-i get nodes --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get pods --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get metrics --as=system:serviceaccount:turbo:kubeturbo
```

### アクションが実行されない

#### 1. ポリシー設定の確認

```
Settings → Policies → Automation Policies

確認項目:
- ポリシーが有効になっているか
- スコープが正しく設定されているか
- アクションモードが適切か（Recommend/Automatic）
```

#### 2. アクション履歴の確認

```
Settings → Action History

フィルタ:
- Status: Failed
- Time Range: Last 24 hours

失敗理由を確認:
- Insufficient permissions
- Resource constraints
- Policy restrictions
```

---

## ベストプラクティス

### 1. 段階的な自動化

```
フェーズ 1: 監視のみ（1-2週間）
- Mode: Recommend
- すべてのアクションを手動で確認

フェーズ 2: 部分的な自動化（2-4週間）
- Mode: Automatic（開発環境のみ）
- 本番環境は Recommend のまま

フェーズ 3: 完全な自動化
- Mode: Automatic（すべての環境）
- 重要なアクションのみ Manual Approval
```

### 2. 定期的なレビュー

```
週次レビュー:
- アクション履歴の確認
- コスト削減効果の測定
- ポリシーの調整

月次レビュー:
- 長期トレンドの分析
- キャパシティプランニング
- ポリシーの最適化
```

### 3. ドキュメント化

```
記録すべき情報:
- ポリシー設定の変更履歴
- 重要なアクションの実行記録
- トラブルシューティングの記録
- パフォーマンス改善の記録
```

---

## 次のステップ

Turbonomic の接続設定が完了したら、以下のドキュメントを参照してください：

1. **[動作確認](04-verification.md)** - システム全体の動作確認
2. **[トラブルシューティング](05-troubleshooting.md)** - 問題が発生した場合の対処方法
3. **[アップグレード手順](06-upgrade.md)** - Kubeturbo のアップグレード方法

---

## 参考リンク

- [Turbonomic ドキュメント - Kubernetes Target](https://www.ibm.com/docs/en/tarm/8.x?topic=targets-kubernetes)
- [Turbonomic ドキュメント - Policies](https://www.ibm.com/docs/en/tarm/8.x?topic=policies-automation-policies)
- [Turbonomic ドキュメント - Actions](https://www.ibm.com/docs/en/tarm/8.x?topic=actions-action-types)
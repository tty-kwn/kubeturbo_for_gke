# 動作確認

Kubeturbo のインストールと Turbonomic への接続が完了したら、システム全体の動作を確認します。

## 目次

- [基本的な動作確認](#基本的な動作確認)
- [Kubernetes クラスタでの確認](#kubernetes-クラスタでの確認)
- [Turbonomic UI での確認](#turbonomic-ui-での確認)
- [メトリクス収集の確認](#メトリクス収集の確認)
- [アクション生成の確認](#アクション生成の確認)
- [パフォーマンステスト](#パフォーマンステスト)
- [自動化スクリプト](#自動化スクリプト)

---

## 基本的な動作確認

### 1. Pod の状態確認

```bash
# Pod が Running 状態であることを確認
kubectl get pods -n turbo

# 期待される出力:
# NAME                         READY   STATUS    RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   1/1     Running   0          10m
```

**確認ポイント:**
- ✓ STATUS が `Running`
- ✓ READY が `1/1`
- ✓ RESTARTS が 0 または少ない回数

### 2. ログの確認

```bash
# 最新のログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=50

# エラーがないか確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i error

# 接続成功のメッセージを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "connected\|registered"
```

**正常なログの例:**

```
I0304 10:00:00.000000       1 kubeturbo.go:123] Starting Kubeturbo version 8.14.3
I0304 10:00:01.000000       1 kubeturbo.go:456] Successfully connected to Turbonomic server
I0304 10:00:02.000000       1 kubeturbo.go:789] Cluster discovery started
I0304 10:00:05.000000       1 kubeturbo.go:890] Successfully registered target: gke-cluster
I0304 10:00:10.000000       1 kubeturbo.go:901] Discovery completed: 3 nodes, 45 pods
```

### 3. イベントの確認

```bash
# namespace のイベントを確認
kubectl get events -n turbo --sort-by='.lastTimestamp'

# Pod のイベントを確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo | grep -A 10 Events
```

**正常なイベントの例:**

```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  10m   default-scheduler  Successfully assigned turbo/kubeturbo-xxx to node-1
  Normal  Pulling    10m   kubelet            Pulling image "icr.io/cpopen/turbonomic/kubeturbo:8.14.3"
  Normal  Pulled     9m    kubelet            Successfully pulled image
  Normal  Created    9m    kubelet            Created container kubeturbo
  Normal  Started    9m    kubelet            Started container kubeturbo
```

---

## Kubernetes クラスタでの確認

### 1. Service Account の確認

```bash
# Service Account の存在確認
kubectl get serviceaccount kubeturbo -n turbo

# Workload Identity のアノテーション確認
kubectl get serviceaccount kubeturbo -n turbo -o yaml | grep -A 2 annotations
```

**期待される出力:**

```yaml
annotations:
  iam.gke.io/gcp-service-account: kubeturbo@PROJECT_ID.iam.gserviceaccount.com
```

### 2. RBAC 権限の確認

```bash
# ClusterRole の確認
kubectl get clusterrole kubeturbo

# ClusterRoleBinding の確認
kubectl get clusterrolebinding kubeturbo

# 権限の詳細確認
kubectl describe clusterrole kubeturbo
```

**必要な権限の確認:**

```bash
# ノードへのアクセス権限
kubectl auth can-i get nodes --as=system:serviceaccount:turbo:kubeturbo

# Pod へのアクセス権限
kubectl auth can-i get pods --as=system:serviceaccount:turbo:kubeturbo

# メトリクスへのアクセス権限
kubectl auth can-i get pods/metrics --as=system:serviceaccount:turbo:kubeturbo
```

すべて `yes` が返ることを確認してください。

### 3. Secret の確認

```bash
# Secret の存在確認
kubectl get secret turbonomic-credentials -n turbo

# Secret の内容確認（デコード）
kubectl get secret turbonomic-credentials -n turbo -o jsonpath='{.data.turboUsername}' | base64 -d
echo ""
kubectl get secret turbonomic-credentials -n turbo -o jsonpath='{.data.turboPassword}' | base64 -d
echo ""
```

### 4. リソース使用状況の確認

```bash
# Pod のリソース使用状況
kubectl top pod -n turbo

# 期待される出力:
# NAME                         CPU(cores)   MEMORY(bytes)
# kubeturbo-xxxxxxxxxx-xxxxx   50m          500Mi

# リソース要求と制限の確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo | grep -A 5 "Limits\|Requests"
```

---

## Turbonomic UI での確認

### 1. ターゲットの接続状態

```
1. Turbonomic UI にログイン
2. Settings → Target Configuration に移動
3. Kubernetes ターゲットを確認

期待される状態:
✓ Status: Validated (緑色)
✓ Last Validated: 最近の時刻
✓ Connection: Active
```

### 2. 検出されたエンティティ

```
ターゲットの詳細画面で確認:

✓ Cluster: 1
✓ Nodes: X個（実際のノード数）
✓ Namespaces: Y個
✓ Pods: Z個
✓ Containers: W個
✓ Services: V個
✓ Volumes: U個
```

### 3. クラスタトポロジーの表示

```
1. Search → Kubernetes を選択
2. クラスタ名をクリック
3. トポロジービューが表示される

確認項目:
✓ ノードが正しく表示されている
✓ Pod が各ノードに配置されている
✓ リソース使用率が表示されている
✓ 接続関係が正しく表示されている
```

### 4. メトリクスの表示

```
クラスタまたはノードを選択して確認:

✓ CPU Utilization: リアルタイムで更新
✓ Memory Utilization: リアルタイムで更新
✓ Network Throughput: データが表示される
✓ Storage Usage: データが表示される
```

---

## メトリクス収集の確認

### 1. ノードメトリクスの確認

```bash
# Kubernetes メトリクスサーバーの確認
kubectl top nodes

# 期待される出力:
# NAME     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
# node-1   500m         25%    4Gi             50%
# node-2   600m         30%    5Gi             62%
# node-3   400m         20%    3Gi             37%
```

### 2. Pod メトリクスの確認

```bash
# すべての Pod のメトリクス
kubectl top pods -A

# 特定の namespace のメトリクス
kubectl top pods -n default
```

### 3. Kubeturbo のメトリクス収集ログ

```bash
# メトリクス収集のログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "metric\|discovery"

# 期待されるログ:
# I0304 10:00:00.000000       1 discovery.go:123] Starting discovery cycle
# I0304 10:00:05.000000       1 discovery.go:456] Collected metrics for 3 nodes
# I0304 10:00:10.000000       1 discovery.go:789] Collected metrics for 45 pods
# I0304 10:00:15.000000       1 discovery.go:890] Discovery cycle completed
```

### 4. Turbonomic UI でのメトリクス確認

```
1. Dashboard に移動
2. Cluster を選択
3. Metrics タブを確認

確認項目:
✓ CPU: グラフが表示され、データが更新される
✓ Memory: グラフが表示され、データが更新される
✓ Network: データが表示される
✓ Storage: データが表示される
✓ 時系列データ: 過去のデータが蓄積されている
```

---

## アクション生成の確認

### 1. 推奨アクションの確認

```
Turbonomic UI で確認:

1. Dashboard → Pending Actions を確認
2. アクションが生成されているか確認

期待されるアクション（例）:
- Resize Container: CPU/メモリの最適化
- Scale Pod: レプリカ数の調整
- Move Pod: ノード間の負荷分散
```

### 2. アクションの詳細確認

```
アクションをクリックして確認:

✓ Action Type: アクションの種類
✓ Target: 対象のリソース
✓ Current State: 現在の状態
✓ Recommended State: 推奨される状態
✓ Impact: 影響の予測
✓ Reason: アクションの理由
```

### 3. アクション生成のテスト

意図的に負荷をかけてアクションが生成されるか確認：

```bash
# テスト用の高負荷 Pod をデプロイ
kubectl run stress-test \
  --image=polinux/stress \
  --restart=Never \
  --requests='cpu=100m,memory=128Mi' \
  --limits='cpu=100m,memory=128Mi' \
  -- stress --cpu 1 --timeout 300s

# 数分待ってから Turbonomic UI でアクションを確認
# 期待されるアクション: Container Resize（CPU 増加の推奨）

# テスト Pod の削除
kubectl delete pod stress-test
```

---

## パフォーマンステスト

### 1. 検出時間の測定

```bash
# Kubeturbo を再起動して検出時間を測定
kubectl rollout restart deployment kubeturbo -n turbo

# ログで検出完了までの時間を確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo -f | grep -i "discovery"

# 期待される時間:
# - 小規模クラスタ（< 10 ノード）: 1-2 分
# - 中規模クラスタ（10-50 ノード）: 2-5 分
# - 大規模クラスタ（> 50 ノード）: 5-10 分
```

### 2. リソース使用量の確認

```bash
# Kubeturbo のリソース使用量を監視
watch kubectl top pod -n turbo

# 期待される使用量:
# CPU: 50-200m（通常時）
# Memory: 500Mi-1Gi（通常時）
```

### 3. API 応答時間の確認

```bash
# Kubernetes API への負荷を確認
kubectl get --raw /metrics | grep apiserver_request_duration_seconds

# Kubeturbo による API 呼び出しの影響を確認
# 通常、API 応答時間への影響は最小限であるべき
```

---

## 自動化スクリプト

### 検証スクリプトの実行

このリポジトリに含まれる検証スクリプトを使用：

```bash
# スクリプトに実行権限を付与
chmod +x scripts/verify-installation.sh

# 検証スクリプトの実行
./scripts/verify-installation.sh

# 期待される出力:
# ✓ Kubeturbo pod is running
# ✓ Kubeturbo is connected to Turbonomic
# ✓ Metrics are being collected
# ✓ RBAC permissions are correct
# ✓ Workload Identity is configured
# 
# All checks passed!
```

### カスタム検証スクリプトの作成

```bash
#!/bin/bash
# custom-verify.sh

set -e

echo "=== Kubeturbo Verification ==="

# 1. Pod の状態確認
echo "Checking pod status..."
kubectl get pods -n turbo -l app.kubernetes.io/name=kubeturbo | grep Running || exit 1

# 2. ログのエラー確認
echo "Checking for errors in logs..."
ERROR_COUNT=$(kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=100 | grep -i error | wc -l)
if [ $ERROR_COUNT -gt 0 ]; then
  echo "Warning: Found $ERROR_COUNT errors in logs"
fi

# 3. Turbonomic 接続確認
echo "Checking Turbonomic connection..."
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=100 | grep -i "connected\|registered" || exit 1

# 4. メトリクス収集確認
echo "Checking metrics collection..."
kubectl top nodes > /dev/null || exit 1

echo "✓ All checks passed!"
```

---

## トラブルシューティング

### Pod が Running にならない

```bash
# Pod の詳細を確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo

# よくある原因:
# 1. イメージのプルエラー
# 2. リソース不足
# 3. ノードセレクタの不一致（Standard GKE）
# 4. セキュリティポリシー違反（Autopilot GKE）
```

### メトリクスが収集されない

```bash
# メトリクスサーバーの確認
kubectl get deployment metrics-server -n kube-system

# Kubelet への接続確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i kubelet

# RBAC 権限の確認
kubectl auth can-i get nodes/metrics --as=system:serviceaccount:turbo:kubeturbo
```

### Turbonomic に接続できない

```bash
# ネットワーク接続の確認
kubectl exec -n turbo deployment/kubeturbo -- \
  curl -k -I https://your-turbonomic-server.example.com

# DNS 解決の確認
kubectl exec -n turbo deployment/kubeturbo -- \
  nslookup your-turbonomic-server.example.com

# 認証情報の確認
kubectl get secret turbonomic-credentials -n turbo -o yaml
```

---

## チェックリスト

動作確認が完了したら、以下の項目をチェックしてください：

### Kubernetes クラスタ

- [ ] Kubeturbo Pod が Running 状態
- [ ] ログにエラーがない
- [ ] Service Account が正しく設定されている
- [ ] RBAC 権限が正しく設定されている
- [ ] Workload Identity が動作している（使用している場合）
- [ ] リソース使用量が適切な範囲内

### Turbonomic UI

- [ ] ターゲットが Validated 状態
- [ ] クラスタが正しく表示されている
- [ ] ノードが検出されている
- [ ] Pod が検出されている
- [ ] メトリクスがリアルタイムで更新されている
- [ ] トポロジービューが正しく表示されている

### メトリクスとアクション

- [ ] CPU メトリクスが収集されている
- [ ] メモリメトリクスが収集されている
- [ ] ネットワークメトリクスが収集されている
- [ ] 推奨アクションが生成されている
- [ ] アクションの詳細が表示される

### パフォーマンス

- [ ] 検出時間が許容範囲内
- [ ] リソース使用量が適切
- [ ] API への影響が最小限

---

## 次のステップ

動作確認が完了したら、以下のドキュメントを参照してください：

1. **[トラブルシューティング](05-troubleshooting.md)** - 問題が発生した場合の対処方法
2. **[アップグレード手順](06-upgrade.md)** - Kubeturbo のアップグレード方法

---

## 参考リンク

- [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Turbonomic ドキュメント - Validation](https://www.ibm.com/docs/en/tarm/8.x?topic=targets-validating-target)
- [GKE モニタリング](https://cloud.google.com/kubernetes-engine/docs/how-to/monitoring)
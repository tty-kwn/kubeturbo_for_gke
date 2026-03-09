# アップグレード手順

Kubeturbo を新しいバージョンにアップグレードする手順を説明します。

## 目次

- [アップグレード前の準備](#アップグレード前の準備)
- [アップグレード方法](#アップグレード方法)
- [ロールバック手順](#ロールバック手順)
- [バージョン別の注意事項](#バージョン別の注意事項)
- [アップグレード後の確認](#アップグレード後の確認)
- [トラブルシューティング](#トラブルシューティング)

---

## アップグレード前の準備

### 1. 現在のバージョンの確認

```bash
# Helm リリースの確認
helm list -n turbo

# Pod のイメージバージョン確認
kubectl get deployment kubeturbo -n turbo -o jsonpath='{.spec.template.spec.containers[0].image}'

# 出力例: icr.io/cpopen/turbonomic/kubeturbo:8.14.3
```

### 2. 利用可能な新バージョンの確認

```bash
# Helm リポジトリの更新
helm repo update

# 利用可能なバージョンの一覧
helm search repo turbonomic/kubeturbo --versions

# 出力例:
# NAME                    CHART VERSION   APP VERSION     DESCRIPTION
# turbonomic/kubeturbo    8.14.4          8.14.4          Kubeturbo for Kubernetes
# turbonomic/kubeturbo    8.14.3          8.14.3          Kubeturbo for Kubernetes
# turbonomic/kubeturbo    8.14.2          8.14.2          Kubeturbo for Kubernetes
```

### 3. リリースノートの確認

新バージョンのリリースノートを確認してください：

- [Kubeturbo Releases](https://github.com/turbonomic/kubeturbo/releases)
- [Turbonomic Documentation](https://www.ibm.com/docs/en/tarm)

**確認すべき項目:**
- 新機能
- バグ修正
- 破壊的変更（Breaking Changes）
- 非推奨機能（Deprecated Features）
- 必要な前提条件の変更

### 4. バックアップの作成

```bash
# 現在の設定をバックアップ
helm get values kubeturbo -n turbo > backup-values-$(date +%Y%m%d).yaml

# すべてのリソースをバックアップ
kubectl get all -n turbo -o yaml > backup-resources-$(date +%Y%m%d).yaml

# Secret のバックアップ
kubectl get secret turbonomic-credentials -n turbo -o yaml > backup-secret-$(date +%Y%m%d).yaml

# ConfigMap のバックアップ（存在する場合）
kubectl get configmap -n turbo -o yaml > backup-configmap-$(date +%Y%m%d).yaml
```

### 5. メンテナンスウィンドウの設定

アップグレード中は以下の影響があります：

- **メトリクス収集の一時停止**: 数分間
- **Turbonomic UI での表示**: 一時的に古いデータが表示される
- **アクションの実行**: アップグレード中は実行されない

**推奨:**
- 低トラフィック時間帯に実施
- 重要なアクションが予定されていない時間帯を選択
- チームメンバーに事前通知

---

## アップグレード方法

### 方法 1: Helm upgrade コマンド（推奨）

#### 1. 最新バージョンへのアップグレード

```bash
# 最新バージョンにアップグレード
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-standard-gke.yaml

# または Autopilot の場合
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-autopilot-gke.yaml
```

#### 2. 特定バージョンへのアップグレード

```bash
# 特定のバージョンを指定
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-standard-gke.yaml \
  --version 8.14.4
```

#### 3. ドライランでの確認

```bash
# アップグレード前にドライランで確認
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-standard-gke.yaml \
  --dry-run --debug
```

### 方法 2: values ファイルの更新を含むアップグレード

```bash
# 新しい values ファイルを準備
cp values/values-standard-gke.yaml /tmp/new-values.yaml

# 必要に応じて編集
vim /tmp/new-values.yaml

# 新しい values でアップグレード
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f /tmp/new-values.yaml
```

### 方法 3: イメージタグのみを更新

```bash
# イメージタグのみを変更
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values/values-standard-gke.yaml \
  --set image.tag=8.14.4
```

### アップグレードの進行状況確認

```bash
# アップグレードの状態確認
helm status kubeturbo -n turbo

# Pod のローリングアップデート確認
kubectl rollout status deployment kubeturbo -n turbo

# 新しい Pod の起動確認
kubectl get pods -n turbo -w

# ログの確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo -f
```

---

## ロールバック手順

アップグレードに問題が発生した場合、以前のバージョンにロールバックできます。

### 1. Helm でのロールバック

```bash
# リビジョン履歴の確認
helm history kubeturbo -n turbo

# 出力例:
# REVISION  UPDATED                   STATUS      CHART              DESCRIPTION
# 1         2026-03-01 10:00:00 JST   superseded  kubeturbo-8.14.3   Install complete
# 2         2026-03-04 11:00:00 JST   deployed    kubeturbo-8.14.4   Upgrade complete

# 直前のバージョンにロールバック
helm rollback kubeturbo -n turbo

# 特定のリビジョンにロールバック
helm rollback kubeturbo 1 -n turbo

# ロールバックの確認
kubectl rollout status deployment kubeturbo -n turbo
```

### 2. 手動でのロールバック

```bash
# Deployment のイメージを直接変更
kubectl set image deployment/kubeturbo \
  kubeturbo=icr.io/cpopen/turbonomic/kubeturbo:8.14.3 \
  -n turbo

# ロールバックの確認
kubectl rollout status deployment kubeturbo -n turbo
```

### 3. バックアップからの復元

```bash
# バックアップした values で再インストール
helm uninstall kubeturbo -n turbo
helm install kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f backup-values-20260301.yaml
```

---

## バージョン別の注意事項

### 8.13.x から 8.14.x へのアップグレード

**主な変更点:**
- 新しい API エンドポイントのサポート
- パフォーマンスの改善
- セキュリティの強化

**必要な対応:**
```yaml
# values.yaml の更新が必要な場合
serverMeta:
  version: "8.14"  # バージョンを更新
```

**互換性:**
- Kubernetes 1.24 以降が必要
- Turbonomic Server 8.14 以降を推奨

### 8.12.x から 8.13.x へのアップグレード

**主な変更点:**
- RBAC 権限の変更
- 新しいメトリクスのサポート

**必要な対応:**
```bash
# RBAC の更新が自動的に適用されます
# 手動での対応は不要
```

### メジャーバージョンアップグレード（例: 8.x から 9.x）

**重要:**
- リリースノートを必ず確認
- テスト環境で事前検証
- 段階的なアップグレードを推奨

```bash
# 段階的アップグレードの例
# 8.12.x → 8.13.x → 8.14.x → 9.0.x
```

---

## アップグレード後の確認

### 1. 基本的な動作確認

```bash
# Pod の状態確認
kubectl get pods -n turbo

# 期待される状態:
# NAME                         READY   STATUS    RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# ログの確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=50

# 正常なログの例:
# I0304 11:00:00.000000       1 kubeturbo.go:123] Starting Kubeturbo version 8.14.4
# I0304 11:00:01.000000       1 kubeturbo.go:456] Successfully connected to Turbonomic server
```

### 2. バージョンの確認

```bash
# Helm リリースのバージョン確認
helm list -n turbo

# Pod のイメージバージョン確認
kubectl get deployment kubeturbo -n turbo -o jsonpath='{.spec.template.spec.containers[0].image}'

# ログでバージョン確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "version\|starting"
```

### 3. Turbonomic UI での確認

```
1. Turbonomic UI にログイン
2. Settings → Target Configuration に移動
3. Kubernetes ターゲットを確認

確認項目:
✓ Status: Validated
✓ Last Validated: 最近の時刻
✓ Version: 新しいバージョンが表示される
✓ Discovered Entities: エンティティ数が正常
```

### 4. メトリクス収集の確認

```bash
# メトリクスが収集されているか確認
kubectl top nodes
kubectl top pods -A

# Kubeturbo のログでメトリクス収集を確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo | grep -i "metric\|discovery"
```

### 5. 機能テスト

```bash
# テスト用の Pod をデプロイ
kubectl run test-pod \
  --image=nginx \
  --requests='cpu=100m,memory=128Mi' \
  --limits='cpu=200m,memory=256Mi'

# Turbonomic UI で確認
# - Pod が検出されているか
# - メトリクスが表示されているか
# - アクションが生成されるか

# テスト Pod の削除
kubectl delete pod test-pod
```

---

## トラブルシューティング

### アップグレードが失敗する

#### 症状

```bash
helm upgrade kubeturbo turbonomic/kubeturbo -n turbo -f values.yaml
# Error: UPGRADE FAILED: ...
```

#### 解決方法

**1. リリースの状態確認**

```bash
# リリースの状態を確認
helm status kubeturbo -n turbo

# 失敗したリリースの場合
helm rollback kubeturbo -n turbo
```

**2. リソースの競合**

```bash
# 既存のリソースを確認
kubectl get all -n turbo

# 必要に応じて手動で削除
kubectl delete deployment kubeturbo -n turbo --force --grace-period=0

# 再度アップグレード
helm upgrade kubeturbo turbonomic/kubeturbo -n turbo -f values.yaml
```

### 新しい Pod が起動しない

#### 症状

```bash
kubectl get pods -n turbo
# NAME                         READY   STATUS             RESTARTS   AGE
# kubeturbo-xxxxxxxxxx-xxxxx   0/1     CrashLoopBackOff   5          5m
```

#### 解決方法

```bash
# ログを確認
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo

# イベントを確認
kubectl describe pod -n turbo -l app.kubernetes.io/name=kubeturbo

# よくある原因:
# 1. 設定の互換性問題 → values.yaml を確認
# 2. リソース不足 → リソース要求を調整
# 3. イメージのプルエラー → イメージタグを確認

# ロールバック
helm rollback kubeturbo -n turbo
```

### メトリクスが収集されない

#### 症状

アップグレード後、Turbonomic UI でメトリクスが更新されない。

#### 解決方法

```bash
# Pod を再起動
kubectl rollout restart deployment kubeturbo -n turbo

# RBAC 権限を確認
kubectl auth can-i get nodes --as=system:serviceaccount:turbo:kubeturbo
kubectl auth can-i get pods --as=system:serviceaccount:turbo:kubeturbo

# Metrics Server を確認
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

### Turbonomic サーバーとの互換性問題

#### 症状

```bash
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
# Error: API version mismatch
# Error: Unsupported server version
```

#### 解決方法

```bash
# Turbonomic サーバーのバージョンを確認
# Kubeturbo と Turbonomic Server のバージョン互換性を確認

# 互換性のあるバージョンにダウングレード
helm rollback kubeturbo -n turbo

# または Turbonomic Server をアップグレード
```

---

## アップグレード戦略

### ブルーグリーンデプロイメント

複数のクラスタがある場合、段階的にアップグレード：

```bash
# フェーズ 1: 開発環境
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values-dev.yaml \
  --version 8.14.4

# 動作確認（1-2日）

# フェーズ 2: ステージング環境
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values-staging.yaml \
  --version 8.14.4

# 動作確認（1週間）

# フェーズ 3: 本番環境
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values-production.yaml \
  --version 8.14.4
```

### カナリアデプロイメント

```bash
# 一部のクラスタのみアップグレード
# 問題がなければ残りのクラスタもアップグレード

# クラスタ A（カナリア）
helm upgrade kubeturbo turbonomic/kubeturbo \
  -n turbo \
  -f values-cluster-a.yaml \
  --version 8.14.4

# 24時間監視

# 問題なければクラスタ B, C, D もアップグレード
```

---

## 自動化

### アップグレードスクリプト

```bash
#!/bin/bash
# upgrade-kubeturbo.sh

set -e

VERSION=${1:-"latest"}
VALUES_FILE=${2:-"values/values-standard-gke.yaml"}

echo "=== Kubeturbo Upgrade Script ==="
echo "Target version: $VERSION"
echo "Values file: $VALUES_FILE"

# バックアップ
echo "Creating backup..."
helm get values kubeturbo -n turbo > backup-values-$(date +%Y%m%d-%H%M%S).yaml

# Helm リポジトリの更新
echo "Updating Helm repository..."
helm repo update

# ドライラン
echo "Running dry-run..."
if [ "$VERSION" = "latest" ]; then
  helm upgrade kubeturbo turbonomic/kubeturbo \
    -n turbo \
    -f $VALUES_FILE \
    --dry-run
else
  helm upgrade kubeturbo turbonomic/kubeturbo \
    -n turbo \
    -f $VALUES_FILE \
    --version $VERSION \
    --dry-run
fi

# 確認
read -p "Proceed with upgrade? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Upgrade cancelled."
  exit 0
fi

# アップグレード実行
echo "Upgrading..."
if [ "$VERSION" = "latest" ]; then
  helm upgrade kubeturbo turbonomic/kubeturbo \
    -n turbo \
    -f $VALUES_FILE
else
  helm upgrade kubeturbo turbonomic/kubeturbo \
    -n turbo \
    -f $VALUES_FILE \
    --version $VERSION
fi

# 進行状況確認
echo "Waiting for rollout to complete..."
kubectl rollout status deployment kubeturbo -n turbo

# 動作確認
echo "Verifying upgrade..."
kubectl get pods -n turbo
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo --tail=20

echo "✓ Upgrade completed successfully!"
```

使用方法：

```bash
# 最新バージョンにアップグレード
./upgrade-kubeturbo.sh

# 特定バージョンにアップグレード
./upgrade-kubeturbo.sh 8.14.4

# カスタム values ファイルを使用
./upgrade-kubeturbo.sh 8.14.4 /path/to/custom-values.yaml
```

---

## チェックリスト

アップグレード前：
- [ ] 現在のバージョンを確認
- [ ] 新バージョンのリリースノートを確認
- [ ] バックアップを作成
- [ ] メンテナンスウィンドウを設定
- [ ] チームに通知

アップグレード中：
- [ ] ドライランで確認
- [ ] アップグレードを実行
- [ ] ローリングアップデートを監視
- [ ] ログを確認

アップグレード後：
- [ ] Pod の状態を確認
- [ ] バージョンを確認
- [ ] Turbonomic UI で確認
- [ ] メトリクス収集を確認
- [ ] 機能テストを実行
- [ ] ドキュメントを更新

---

## 参考リンク

- [Kubeturbo Releases](https://github.com/turbonomic/kubeturbo/releases)
- [Helm Upgrade Documentation](https://helm.sh/docs/helm/helm_upgrade/)
- [Kubernetes Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Turbonomic Upgrade Guide](https://www.ibm.com/docs/en/tarm/8.x?topic=upgrading)
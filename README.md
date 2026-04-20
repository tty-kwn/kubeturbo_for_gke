# Kubeturbo for Google Kubernetes Engine (GKE)

IBM Turbonomic の Kubeturbo を Google Kubernetes Engine (GKE) 環境に導入するための包括的なガイドです。

## 📋 概要

このリポジトリは、GKE 環境（Standard および Autopilot）に Kubeturbo をデプロイするための、実践的な設定ファイルとドキュメントを提供します。公式の Helm Chart を使用し、GKE 固有の設定や最適化を適用します。

## 注意点

GKE Autopilot は Google Cloud Platform側の制約のため、Turbonomic の最適化提案が一部制限されます。

### Kubeturbo とは

Kubeturbo は、Kubernetes クラスタのリソース管理を自動化する IBM Turbonomic のエージェントです。以下の機能を提供します：

- **リアルタイムリソース監視**: CPU、メモリ、ストレージの使用状況を継続的に監視
- **自動スケーリング**: ワークロードの需要に基づいて Pod とノードを自動調整
- **コスト最適化**: リソースの過剰プロビジョニングを削減し、クラウドコストを最適化
- **パフォーマンス保証**: アプリケーションのパフォーマンスを維持しながらリソースを最適化

## 🎯 対象環境

- **GKE Standard クラスタ**: フルコントロールが可能な標準的な GKE クラスタ
- **GKE Autopilot クラスタ**: Google が管理する最適化された GKE クラスタ

## 🚀 クイックスタート

### 前提条件

- GKE クラスタが稼働していること
- `kubectl` がクラスタに接続されていること
- `helm` (v3.x) がインストールされていること
- Turbonomic サーバーへのアクセス情報（URL、認証情報）

### インストール手順

#### 1. Helm リポジトリの追加

```bash
helm repo add turbonomic https://turbonomic.github.io/t8c-install
helm repo update
```

#### 2. GKE タイプに応じた values ファイルの選択

**Standard GKE の場合:**
```bash
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f values/values-standard-gke.yaml \
  --set serverMeta.turboServer=<YOUR_TURBO_SERVER_URL> \
  --set targetConfig.targetName=<YOUR_CLUSTER_NAME>
```

**Autopilot GKE の場合:**
```bash
helm install kubeturbo turbonomic/kubeturbo \
  --namespace turbo \
  --create-namespace \
  -f values/values-autopilot-gke.yaml \
  --set serverMeta.turboServer=<YOUR_TURBO_SERVER_URL> \
  --set targetConfig.targetName=<YOUR_CLUSTER_NAME>
```

#### 3. インストールの確認

```bash
kubectl get pods -n turbo
kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo
```

## 📚 ドキュメント

詳細なドキュメントは `docs/` ディレクトリにあります：

1. **[事前準備](docs/01-prerequisites.md)** - GKE クラスタの準備と必要な権限設定
2. **[インストール手順](docs/02-installation.md)** - ステップバイステップのインストールガイド
3. **[Turbonomic 接続設定](docs/03-turbonomic-connection.md)** - Turbonomic サーバーへの接続設定
4. **[動作確認](docs/04-verification.md)** - インストール後の動作確認方法
5. **[トラブルシューティング](docs/05-troubleshooting.md)** - よくある問題と解決方法
6. **[アップグレード手順](docs/06-upgrade.md)** - Kubeturbo のアップグレード方法

## 📁 ファイル構成

```
turbo-kubeturbo_for_gke/
├── README.md                          # このファイル
├── values/
│   ├── values-standard-gke.yaml       # Standard GKE 用設定
│   ├── values-autopilot-gke.yaml      # Autopilot GKE 用設定
│   └── values-custom-example.yaml     # カスタマイズ例
├── docs/
│   ├── 01-prerequisites.md            # 事前準備
│   ├── 02-installation.md             # インストール手順
│   ├── 03-turbonomic-connection.md    # Turbonomic 接続設定
│   ├── 04-verification.md             # 動作確認
│   ├── 05-troubleshooting.md          # トラブルシューティング
│   └── 06-upgrade.md                  # アップグレード手順
└── scripts/
    ├── setup-gke-prerequisites.sh     # GKE 事前設定スクリプト
    ├── install-kubeturbo.sh           # インストールスクリプト
    └── verify-installation.sh         # 検証スクリプト
```

## 🔧 主な設定項目

### Standard GKE の特徴

- フルコントロール可能なノード設定
- カスタム DaemonSet のサポート
- 柔軟なリソース割り当て
- ノードプールの詳細な制御

### Autopilot GKE の特徴

- Google による自動管理
- セキュリティ制約（特権コンテナ不可など）
- 自動スケーリングとパッチ適用
- リソース要求の厳密な管理

## 🔐 セキュリティ

このガイドでは、以下のセキュリティベストプラクティスを採用しています：

- **Kubernetes Secret** による認証情報の安全な管理
- **Workload Identity** を使用した GCP サービスとの統合（推奨）
- **最小権限の原則** に基づく RBAC 設定
- **ネットワークポリシー** によるトラフィック制御

## 🤝 サポートとコントリビューション

### 問題が発生した場合

1. [トラブルシューティングガイド](docs/05-troubleshooting.md) を確認
2. ログを確認: `kubectl logs -n turbo -l app.kubernetes.io/name=kubeturbo`
3. GitHub Issues で報告

### コントリビューション

プルリクエストを歓迎します！以下の点にご協力ください：

- 明確な説明とテスト結果を含める
- ドキュメントの更新も含める
- GKE Standard と Autopilot の両方で動作確認

## 📖 参考リンク

- [IBM Turbonomic 公式ドキュメント](https://www.ibm.com/docs/en/tarm)
- [Kubeturbo GitHub リポジトリ](https://github.com/turbonomic/kubeturbo)
- [GKE ドキュメント](https://cloud.google.com/kubernetes-engine/docs)
- [Helm 公式ドキュメント](https://helm.sh/docs/)

## 📄 ライセンス

このガイドは MIT ライセンスの下で公開されています。Kubeturbo 自体のライセンスについては、[公式リポジトリ](https://github.com/turbonomic/kubeturbo)を参照してください。

## 🏷️ バージョン情報

- **ガイドバージョン**: 1.0.0
- **対応 Kubeturbo バージョン**: 8.x 以降
- **対応 GKE バージョン**: 1.27 以降
- **最終更新日**: 2026-03-04

---

**注意**: このガイドは非公式のものです。最新の情報については、必ず [IBM Turbonomic 公式ドキュメント](https://www.ibm.com/docs/en/tarm) を参照してください。

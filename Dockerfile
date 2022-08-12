#ベースイメージを指定するために必要
#記述方法　「ベースイメージ：タグ」※タグはなくても問題なし（していなければ最新のものがインストールされる）
FROM ruby:2.7.1-alpine

# ARGはdockerファイル内で使用する変数を定義
# .envで定義した環境変数をdocker-compose.ymlで読込、
# dockerfileに渡している(appが入る)
ARG WORKDIR
#linux-headers libxml2-dev はベースイメージに存在するので削除
ARG RUNTIME_PACKAGES="make gcc libc-dev nodejs tzdata postgresql-dev postgresql git"
ARG DEV_PACKAGES="build-base curl-dev"

#環境変数を定義(dokerfile, コンテナ参照可)
#rails ENV["TZ"] => Asia/Tokyo
ENV HOME=/${WORKDIR} \
    LANG=C.UTF-8 \
    TZ=Asia/Tokyo

#ベースイメージに対してコマンドを実行する 
#テスト命令なのでコメントアウトしておく
# RUN echo ${HOME}

#dockerfile内で指定した命令を実行する...RUN, COPY, ENTRYPOINT, CMD
#作業ディレクトリを定義
# コンテナ/app/Railsアプリ
WORKDIR ${HOME}

#ホスト側のファイルをコンテナにコピー
#COPY コピー元(ホスト) コピー先(コンテナ)
#コピー元(ホスト)... dockerfileがあるディレクトリ以下を指定する(api) 上のディレクトリはNG(../)
#コピー先(コンテナ)... 絶対パス、相対パスでもok(ここではカレントディレクトリを指定(appディレクトリ直下))
COPY Gemfile* ./

#apkはalpinelinuxのコマンド
#apk update 利用可能な最新パッケージのリストを取得
#apk upgrade インストールパッケージを最新にする
#apk add パッケージのインストールを実行する(no cache　パッケージをキャッシュせずdockerイメージを軽量化)
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ${RUNTIME_PACKAGES} && \
    # --virtual 仮想パッケージ(DEV_PACKAGESで指定したパッケージをひとまとめ(build-dependenciesで)にする)
    apk add --virtual build-dependencies --no-cache ${DEV_PACKAGES} && \
    # j4オプション(jobs=4) gemのインストールの並列処理、gemインストールの高速化
    bundle install -j4 && \
    # インストール後にパッケージ削除(bundle install後不要になるため)
    apk del build-dependencies

#dockerファイルがあるディレクトリ(apiディレクトリ直下)全てのファイルをコンテナのカレントディレクトリにコピー
COPY . ./

#コンテナ内で実行したいコマンドを定義
#railsサーバを起動させる　bオプションはbindのことでプロセスを指定したipアドレスで実行
CMD ["rails", "server", "-b", "0.0.0.0"]

# 通常コンテナ内で起動したrailsは外部のブラウザからアクセスできない
# ホスト(PC)　　　｜ コンテナ
# ブラウザ(外部)  |  rails 
# ※127.0.0.1でlistenしてもそれはDockerコンテナのローカル環境であり、
# PCのローカルipをブラウザで指定してもアクセスできない(ポートフォワーディング等しない限り)
# 0.0.0.0でサーバーを立てると、
# そのホストの全てのインターフェースでlistenします．(同一ネットワーク内の別ホストから(ローカルマシンからも)アクセス可能)
# 本来0.0.0.0にリクエストを投げても無効だがdockerが起動している場合はOSがよしなに宛先を認識してくれる(dockerの環境)
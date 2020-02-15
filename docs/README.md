# はじめに

GarnetはRubyの処理系を持つプログラミング言語です。

Garnetの実行ファイルには、拡張子`.gar`を使用します。

### 実行権限の付与

`garnet`ファイルから実行できるようにするためには、以下のファイルに実行権限を付与します。

```sh
chmod 755 ./garnet
```

### .garファイルを実行

実行権限を付与された`garnet`ファイルを直接呼び出してGarnetプログラムを実行できます。

```sh
./garnet ./sample/helloworld.gar
```

### Garnetインタープリター

ファイル名を指定しないで実行すると、Garnetのインタープリターが起動します。

```sh
./garnet
```

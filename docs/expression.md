# 算術式

Garnetの算術式では、項や演算子の間に空白を挿入することは許されていません。

### 式

> `項 ((‘+’|’-’) 項)*`

式は、1つ以上の項の加算および減算からなります。

### 項

> `因子 ((‘*’|’/’) 因子)*`

項は、1つ以上の因子の乗算および除算からなります。

### 因子

> `リテラル | 変数 | (式) | "文字列"`

因子とは、リテラル、変数、()で囲まれた式、""で囲まれた文字列のいずれかを表します。
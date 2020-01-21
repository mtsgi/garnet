#!/usr/bin/ruby

require 'strscan'

class Garnet
  def initialize
    f = open(ARGV[0])
    code = f.map {|l| l.chomp }.join('') # read
    puts code
    @@scanner = StringScanner.new(code)
    puts @@scanner
    ast = GarnetSyntax.sentences()
    puts ast
    # puts eval(ast)
  end

  def self.get_token
    _keywords = GarnetSyntax::KW.keys.map{ |t|Regexp.escape(t) }
    puts @@scanner
    if ret = @@scanner.scan(/\A\s*(#{ _keywords.join('|') })/) # KWの時はシンボルを返す
      puts 'キーワード:' + ret
      return GarnetSyntax::KW[ret]
    end
    if ret = @@scanner.scan(/\A\s*([A-Za-z_$][A-Za-z_$0-9]*)/) # 変数の時
      puts '変数:' + ret
      return ret
    end
    if ret = @@scanner.scan(/\A\s*([0-9.]+)/) # 数値リテラル そのまま返す
      puts '数値リテラル:' + ret
      return ret.to_f
    end
    if ret = @@scanner.scan(/\A\s*\z/) # 空白は除去
      return nil
    end
    return ret.to_s
  end

  def self.unget_token()
    @@scanner.unscan
  end
end

class GarnetSyntax < Garnet # tokenizer
  KW = {
    '+': :add,
    '-': :sub,
    '*': :mul,
    '/': :div,
    '%': :mod,
    '(': :lpar,
    ')': :rpar,
    '{': :lblock, # start of block
    '}': :rblock, # end of block
    ';': :eos, # end of statement
    '=': :assign,
    'if': :if,
    'then': :then,
    'else': :else
  }

  def self.sentences # 文列(block) = 文(文)*
    result = [:block]
    if s =  GarnetSyntax.sentence()
      result << s
    #else
      #raise 'SentenseNotFoundException'
    end
    while s = GarnetSyntax.sentence()
      result << s
    end
    puts '[文列]'
    puts result
    result
  end

  def self.sentence # 文 = 代入文|いふ文|hoge文|{文列}
    token = get_token()
    if token == :lblock # 文列のとき
      result = GarnetSyntax.sentences() # [:block, ~~~]が返る
      unless get_token == :rblock # }がない
        raise 'RBlockNotFoundException'
      end
      return result
    end
    unget_token()

    if result = GarnetSyntax.assignment() # nilが返ると次に行く
      puts '[代入文]'
      puts result
      return result
    end
    if result = GarnetSyntax.print()
      puts '[print文]'
      puts result
      return result
    end
    if result = GarnetSyntax.ifthenelse()
      return result
    end
  end

  def self.assignment
    token = get_token()
    puts "次トークン:#{token}"
    if token.is_a? String # 変数として正しい
      token = get_token()
      puts "次トークン:#{token = get_token()}"
      result = [:assignment, [:var, token], GarnetSyntax.expression()]
      # もし関数呼び出しだったら…？ => n個(先読みの深さ)ungetしてnilを返す
      # 先読みの個数は減らしたい
      # FUNC() と var みたいに区別させれば深くならない
      unless token == :eos
        puts 'エラー前トークン:' + token.to_s
        raise 'E'
      end
      return result # 木を返す
    else
      unget_token()
      return nil
    end
  end



  def self.expression # 式 = Term ((‘+’|’-’) Term)*
    result = GarnetSyntax.term()
    while true
      token = get_token()
      unless token == :add or token == :sub
        unget_token()
        break
      end
      result = [token, result, term]
    end
    puts '[式]'
    puts result
    return result
  end

  def self.term # 項 = Fctr ((‘*’|’/’) Fctr)*
    result = GarnetSyntax.factor()
    while true
      token = get_token()
      unless token == :mul or token == :div
        unget_token()
        break
      end
      result = [token, result, factor]
    end
    puts '[項]'
    puts result
    return result
  end

  def self.factor # 因子 = リテラル | 変数 | (式)
    while true
      token = get_token()
      if token
        unget_token()
        break
      end
    end
    minusflg = 1
    if token == :sub
      minusflg = -1
      token = get_token()
    end
    if token.is_a? Numeric # 数値リテラル
      puts '[因子]'
      puts token * minusflg
      return token * minusflg
    elsif token == :lpar # (式)のとき
      result = GarnetSyntax.expression()
      unless get_token() == :rpar
        raise Exception, "Unexpected token : #{:rpar}"
      end
      puts '[因子]'
      puts [:mul, minusflg, result]
      return [:mul, minusflg, result]
    else
      raise 'UnexpectedTokenException'
    end
  end
end

Garnet.new()

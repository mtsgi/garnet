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
    puts "抽象構文木 => #{ast}"
    # puts eval(ast)
  end

  def self.get_token
    _keywords = GarnetSyntax::KW.keys.map{ |t|Regexp.escape(t) }
    if ret = @@scanner.scan(/\A\s*(#{ _keywords.join('|') })/) # KWの時はシンボルを返す
      puts "<get_token> キーワード: #{ret}"
      return ret
      # return GarnetSyntax::KW[ret]
    end
    if ret = @@scanner.scan(/\A\s*([A-Za-z_$][A-Za-z_$0-9]*)/) # 変数の時
      puts "<get_token> 変数: #{ret}"
      return ret.strip
    end
    if ret = @@scanner.scan(/\A\s*([0-9.]+)/) # 数値リテラル そのまま返す
      puts '<get_token> 数値リテラル:' + ret
      return ret.to_f
    end
    if ret = @@scanner.scan(/\A\s*\z/) # 空白は除去
      return nil
    end
    puts "<get_token> 不明トークン: #{ret}"
    return ret.to_s
  end

  def self.unget_token()
    puts '=> UNGET'
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
    '{': :lblock,
    '}': :rblock,
    ';': :eos,
    '=': :assign,
    'if': :if,
    'then': :then,
    'else': :else,
    'print': :print,
    'input': :input
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
    puts "[文列] #{result}"
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

    if result = GarnetSyntax.print() # nilが返ると次に行く
      puts "[print文]#{result}"
      return result
    end
    if result = GarnetSyntax.input()
      puts "[input文]#{result}"
      return result
    end
    if result = GarnetSyntax.assignment()
      puts "[代入文]#{result}"
      return result
    end
    return nil
  end

  def self.print # print文 = print 式
    token = get_token()
    if token == :print.to_s
      result = GarnetSyntax.expression()
      if get_token() == ';'
        puts "プリント => #{result}"
        return [:print, result]
      else
        unget_token()
        return nil
      end
    else
      unget_token()
      return nil
    end
  end

  def self.input # input文 = input 式
    token = get_token()
    if token == :input.to_s
      result = GarnetSyntax.expression()
      if get_token() == ';'
        puts "インプット => #{result}"
        return [:input, result]
      else
        unget_token()
        return nil
      end
    else
      unget_token()
      return nil
    end
  end

  def self.assignment # 代入文 = 変数 = 式
    token = get_token()
    puts "変数名トークン => #{token}"
    if token.is_a? String # 変数として正しい
      var = token
      token = get_token()
      puts "代入KWトークン => #{token}"
      if token&.strip == "="
        puts "正しい代入KWです"
      else
        puts "正しくない代入KWです"
        unget_token()
        return nil
      end
      result = [:assignment, [:var, var], GarnetSyntax.expression()]
      puts "結果 => #{result}"
      # もし関数呼び出しだったら…？ => n個(先読みの深さ)ungetしてnilを返す
      # 先読みの個数は減らしたい
      # FUNC() と var みたいに区別させれば深くならない
      unless get_token() == ";"
        puts 'エラー前トークン:' + token.to_s
        raise 'Unex-BeforeEndOfStatement'
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
      puts "リザルト:#{result}"
      token = get_token()

      if token == '+'
        result = [:add, result, GarnetSyntax.term()]
      elsif token == '-'
        result = [:sub, result, GarnetSyntax.term()]
      else
        unget_token()
        break
      end
    end
    puts "[式]#{result}"
    return result
  end

  def self.term # 項 = Fctr ((‘*’|’/’) Fctr)*
    result = GarnetSyntax.factor()
    while true
      token = get_token()
      unless token == '*' or token == '/'
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
    token = get_token()
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
      puts "[変数] #{token}"
      return [:var, token]
    end
  end
end

Garnet.new()

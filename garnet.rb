#!/usr/bin/ruby

require 'strscan'

class Garnet
  @@var = {
    GARNET_VER: 1,
    DEBUG_MODE: 0
  }

  @@scanner_log = []

  def initialize
    f = open(ARGV[0])
    code = f.map {|l| l.chomp }.join('') # read
    Garnet.log code
    @@scanner = StringScanner.new(code)
    @@scanner_log << @@scanner.dup
    Garnet.log @@scanner
    ast = GarnetSyntax.sentences()
    Garnet.log "抽象構文木 => #{ast}"
    Garnet.eval(ast)
    Garnet.log @@var
  end

  def self.log(message)
    puts message if @@var[:DEBUG_MODE] == 1
  end

  def self.get_token
    _keywords = GarnetSyntax::KW.keys.map{ |t|Regexp.escape(t) }
    if ret = @@scanner.scan(/\A\s*"(.*?)[^\\]"|""/) # ""で囲まれた文字列
      @@scanner_log << @@scanner.dup
      self.log "<get_token> 文字列: #{ret}"
      return ret.to_s
    end
    if ret = @@scanner.scan(/\A\s*\[(.*?)[^\[|^\]]\]/) # []で囲まれたもの
      @@scanner_log << @@scanner.dup
      self.log "<get_token> コメント: #{ret}"
      return ret.to_s.strip
    end
    if ret = @@scanner.scan(/\A\s*(#{ _keywords.join('|') })/) # KWの時はシンボルを返す
      @@scanner_log << @@scanner.dup
      self.log "<get_token> キーワード: #{ret}"
      return ret
    end
    if ret = @@scanner.scan(/\A\s*([A-Za-z_$][A-Za-z_$0-9]*)/) # 変数の時
      @@scanner_log << @@scanner.dup
      self.log "<get_token> 変数: #{ret}"
      return ret.strip
    end
    if ret = @@scanner.scan(/\A\s*([0-9.]+)/) # 数値リテラル そのまま返す
      @@scanner_log << @@scanner.dup
      self.log '<get_token> 数値リテラル:' + ret
      return ret.to_f
    end
    if ret = @@scanner.scan(/\A\s*\z/) # 空白は除去
      @@scanner_log << @@scanner.dup
      return nil
    end
    @@scanner_log << @@scanner.dup
    self.log "<get_token> 不明トークン: #{ret}"
    return ret.to_s
  end

  def self.unget_token
    self.log "=> UNGET : #{@@scanner_log.last.inspect}"
    @@scanner = @@scanner_log.last
    @@scanner.unscan()
    @@scanner_log.pop
    # self.log "=> LAST : #{@@scanner_log.last.inspect}"
  end

  def self.eval(ast)
    if ast.instance_of?(Array)
      case ast[0]
      when :block # 文列(block) = 文(文)*
        self.log "ast" + ast[2].to_s
        ast[1..-1].each do |s|
          # self.log "文:" + s.to_s
          Garnet.eval s
        end
      when :assignment
        return @@var[ast[1].intern] = Garnet.eval(ast[2]).to_f
      when :print
        return puts Garnet.eval(ast[1])
      when :var
        return @@var[ast[1].intern] || 'undefined'
      when :string
        return ast[1]
      when :input
        @@var[ast[1].intern] = STDIN.gets().chomp()
        return @@var[ast[1].intern]
      when :add
        left = eval(ast[1])
        if left.is_a? String
          return left.dup << eval(ast[2]).to_s
        else
          return left.to_f + eval(ast[2]).to_f
        end
      when :sub
        return eval(ast[1]).to_f - eval(ast[2]).to_f
      when :mul
        return eval(ast[1]).to_f * eval(ast[2]).to_f
      when :div
        return eval(ast[1]).to_f / eval(ast[2]).to_f
      end
    else
      return ast
    end
  end
end

class GarnetSyntax < Garnet # tokenizer
  KW = {
    '+': :add,
    '-': :sub,
    '*': :mul,
    '/': :div,
    '^': :pow,
    '%': :mod,
    '(': :lpar,
    ')': :rpar,
    '{': :lblock,
    '}': :rblock,
    ';': :eos,
    '<=': :assign,
    '==': :eql,
    'if': :if,
    '?': :then,
    'else': :else,
    '<<': :print,
    '>>': :input,
    '"': :quote
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
    self.log "[文列] #{result}"
    result
  end

  def self.sentence # 文 = 代入文|IF文|~~文|{文列}
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
      self.log "[print文]#{result}"
      return result
    end
    if result = GarnetSyntax.input()
      self.log "[input文]#{result}"
      return result
    end
    if result = GarnetSyntax.ifst()
      self.log "[if文]#{result}"
      return result
    end
    if result = GarnetSyntax.assignment()
      self.log "[代入文]#{result}"
      return result
    end
    if token =~ /\[(.*)\]/
      self.log "[コメント] #{$1}"
      return [:comment, $1]
    end
    return nil
  end

  def self.print # print文 = << 式;
    token = get_token()
    if token == '<<'
      result = GarnetSyntax.expression()
      if get_token() == ';'
        self.log "プリント => #{result}"
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

  def self.input # input文 = >> 変数名;
    token = get_token()
    if token == '>>'.to_s
      token = get_token()
      self.log "変数名トークン => #{token}"
      if token.is_a? String # 変数名として正しい
        var = token
        if get_token() == ';'
          return [:input, var]
        else
          unget_token()
          return nil
        end
      end
    else
      unget_token()
      return nil
    end
  end

  def self.assignment # 代入文 = 変数 <= 式
    token = get_token()
    self.log "変数名トークン => #{token}"
    if token.is_a? String # 変数として正しい
      var = token
      token = get_token()
      self.log "代入KWトークン => #{token}"
      if token&.strip == "<="
        self.log "正しい代入KWです"
      else
        self.log "正しくない代入KWです"
        unget_token()
        return nil
      end
      result = [:assignment, var, GarnetSyntax.expression()]
      self.log "結果 => #{result}"
      # もし関数呼び出しだったら…？ => n個(先読みの深さ)ungetしてnilを返す
      # 先読みの個数は減らしたい
      # FUNC() と var みたいに区別させれば深くならない
      unless get_token() == ";"
        self.log 'エラー前トークン:' + token.to_s
        raise 'Unex-BeforeEndOfStatement'
      end
      return result # 木を返す
    else
      unget_token()
      return nil
    end
  end

  def self.ifst # if文 = 式 ? 文列
    if token = GarnetSyntax.expression()
      self.log "判定式 => #{token}"
      var = token
      thenkw = get_token()
      self.log "thenKWトークン => #{thenkw}"
      unless thenkw&.strip == "?"
        self.log "正しくないthenKWです"
        unget_token()
        unget_token()
        return nil
      end
      result = [:ifst, token, GarnetSyntax.sentences()]
      self.log "結果 => #{result}"
      return result
    else
      unget_token()
      return nil
    end
  end

  def self.expression # 式 = Term ((‘+’|’-’) Term)*
    result = GarnetSyntax.term()
    while true
      self.log "リザルト:#{result}"
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
    self.log "[式]#{result}"
    return result
  end

  def self.term # 項 = Fctr ((‘*’|’/’) Fctr)*
    result = GarnetSyntax.factor()
    while true
      token = get_token()
      unless token == '*' or token == '/' or token == '=='
        unget_token()
        break
      end
      token_sym = :mul if token == '*'
      token_sym = :div if token == '/'
      token_sym = :eql if token == '=='
      result = [token_sym, result, factor]
    end
    self.log '[項]' + result.to_s
    return result
  end

  def self.factor # 因子 = リテラル | 変数 | (式) | "文字列"
    token = get_token()
    minusflg = 1
    if token == :sub
      minusflg = -1
      token = get_token()
    end
    if token.is_a? Numeric # 数値リテラル
      self.log "[因子] #{token * minusflg}"
      return token * minusflg
    elsif token == '(' # (式)のとき
      result = GarnetSyntax.expression()
      unless get_token() == ')'
        raise Exception, "Unexpected token : #{:rpar}"
      end
      self.log "[因子] #{[:mul, minusflg, result]}"
      return [:mul, minusflg, result]
    elsif token =~ /"(.*)"/
      self.log "[文字列] #{$1}"
      return [:string, $1.gsub(/\\"/, '"')]
    else
      self.log "[変数] #{token}"
      return [:var, token]
    end
  end
end

Garnet.new()

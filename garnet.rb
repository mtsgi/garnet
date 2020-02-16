#!/usr/bin/ruby

require 'date'
require 'strscan'
require 'readline'

class Garnet
  @@vars = {
    GARNET_VER: 1.0,
    DEBUG_MODE: 0,
    TODAY: Date.today.strftime,
    COLS: `tput cols`,
    LINES: `tput lines`,
    SHELL: ENV['SHELL']
  }

  @@scanner_log = []

  def initialize
    if ARGV[0]
      f = open(ARGV[0])
      code = f.map {|l| l.chomp }.join('')
      Garnet.log code
      @@scanner = StringScanner.new(code)
      @@scanner_log << @@scanner.dup
      Garnet.log @@scanner
      ast = GarnetSyntax.sentences()
      Garnet.log "抽象構文木 => #{ast}"
      Garnet.eval(ast)
      Garnet.log @@vars
    else
      loop do
        code = Readline.readline("gar > ", true)
        @@scanner = StringScanner.new(code)
        begin
          ast = GarnetSyntax.sentences()
          Garnet.log "抽象構文木 => #{ast}"
          Garnet.eval(ast)
        rescue Exception
          puts Exception
        end
      end
    end
  end

  def self.log(message)
    puts message if @@vars[:DEBUG_MODE] == 1
  end

  def self.get_token
    _keywords = GarnetSyntax::KW.keys.map{ |t|Regexp.escape(t) }
    if ret = @@scanner.scan(/\A\s*"(.*?)[^\\]"|""/)
      @@scanner_log << @@scanner.dup
      self.log "<get_token> 文字列: #{ret}"
      return ret.to_s
    end
    if ret = @@scanner.scan(/\A\s*\[(.*?)[^\[|^\]]\]/)
      @@scanner_log << @@scanner.dup
      self.log "<get_token> コメント: #{ret}"
      return ret.to_s.strip
    end
    if ret = @@scanner.scan(/\A\s*(#{ _keywords.join('|') })/)
      @@scanner_log << @@scanner.dup
      self.log "<get_token> キーワード: #{ret.strip}"
      return ret.strip
    end
    if ret = @@scanner.scan( GarnetSyntax::VAREXP )
      @@scanner_log << @@scanner.dup
      self.log "<get_token> 変数: #{ret}"
      return ret.strip
    end
    if ret = @@scanner.scan(/\A\s*([0-9.]+)/)
      @@scanner_log << @@scanner.dup
      self.log '<get_token> 数値リテラル:' + ret
      return ret.to_f
    end
    if ret = @@scanner.scan(/\A\s*\z/)
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
  end

  def self.eval(ast)
    if ast.instance_of?(Array)
      case ast[0]
      when :block
        self.log "  ast => " + ast[2].to_s
        ast[1..-1].each do |s|
          Garnet.eval(s)
        end
      when :assignment
        exp = Garnet.eval(ast[2])
        exp = exp.to_f if exp.is_a? Numeric
        return @@vars[ast[1].intern] = exp
      when :print
        return puts Garnet.eval(ast[1])
      when :var
        return @@vars[ast[1].intern] || 'undefined'
      when :string
        return ast[1]
      when :input
        @@vars[ast[1].intern] = Readline.readline('', true).chomp()
        return @@vars[ast[1].intern]
      when :add
        left = eval(ast[1])
        if left.is_a? String
          return left.dup << Garnet.eval(ast[2]).to_s
        else
          return left.to_f + Garnet.eval(ast[2]).to_f
        end
      when :sub
        return Garnet.eval(ast[1]).to_f - Garnet.eval(ast[2]).to_f
      when :mul
        return Garnet.eval(ast[1]).to_f * Garnet.eval(ast[2]).to_f
      when :div
        return Garnet.eval(ast[1]).to_f / Garnet.eval(ast[2]).to_f
      when :mod
        return Garnet.eval(ast[1]).to_f % Garnet.eval(ast[2]).to_f
      when :eql
        left = Garnet.eval(ast[1])
        right = Garnet.eval(ast[2])
        self.log "左辺=>#{left} / 右辺=>#{right}"
        if left.is_a? String
          return left.to_s.eql?(right) || left.to_s.eql?(right.to_i.to_s) || left.to_s.eql?(right.to_f.to_s)
        else
          return left.to_f.eql?(right.to_f)
        end
      when :ineql
        return left != right
      when :ifst
        return Garnet.eval(ast[2]) unless GarnetSyntax::FALSY.include? Garnet.eval(ast[1])
      when :exit
        puts 'Exited from garnet.'
        Kernel.exit! 0
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
    '=>': :assign_inv,
    ':)': :eql,
    ':(': :ineql,
    '??': :then,
    '!?': :unless,
    '<<': :print,
    '>>': :input,
    '"': :quote,
    ':/': :exit
  }

  FALSY = [nil, 0, false, '', Float::NAN, 'undefined']

  VAREXP = /\A\s*([A-Za-z_$\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}\u{2194}-\u{2199}\u{21A9}-\u{21AA}\u{231A}-\u{231B}\u{2328}\u{23CF}\u{23E9}-\u{23F3}\u{23F8}-\u{23FA}\u{24C2}\u{25AA}-\u{25AB}\u{25B6}\u{25C0}\u{25FB}-\u{25FE}\u{2600}-\u{2604}\u{260E}\u{2611}\u{2614}-\u{2615}\u{2618}\u{261D}\u{2620}\u{2622}-\u{2623}\u{2626}\u{262A}\u{262E}-\u{262F}\u{2638}-\u{263A}\u{2648}-\u{2653}\u{2660}\u{2663}\u{2665}-\u{2666}\u{2668}\u{267B}\u{267F}\u{2692}-\u{2694}\u{2696}-\u{2697}\u{2699}\u{269B}-\u{269C}\u{26A0}-\u{26A1}\u{26AA}-\u{26AB}\u{26B0}-\u{26B1}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26C8}\u{26CE}-\u{26CF}\u{26D1}\u{26D3}-\u{26D4}\u{26E9}-\u{26EA}\u{26F0}-\u{26F5}\u{26F7}-\u{26FA}\u{26FD}\u{2702}\u{2705}\u{2708}-\u{270D}\u{270F}\u{2712}\u{2714}\u{2716}\u{271D}\u{2721}\u{2728}\u{2733}-\u{2734}\u{2744}\u{2747}\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2763}-\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{27BF}\u{2934}-\u{2935}\u{2B05}-\u{2B07}\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}\u{3030}\u{303D}\u{3297}\u{3299}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F171}\u{1F17E}-\u{1F17F}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F201}-\u{1F202}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}-\u{1F251}\u{1F300}-\u{1F321}\u{1F324}-\u{1F393}\u{1F396}-\u{1F397}\u{1F399}-\u{1F39B}\u{1F39E}-\u{1F3F0}\u{1F3F3}-\u{1F3F5}\u{1F3F7}-\u{1F4FD}\u{1F4FF}-\u{1F53D}\u{1F549}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F56F}-\u{1F570}\u{1F573}-\u{1F579}\u{1F587}\u{1F58A}-\u{1F58D}\u{1F590}\u{1F595}-\u{1F596}\u{1F5A5}\u{1F5A8}\u{1F5B1}-\u{1F5B2}\u{1F5BC}\u{1F5C2}-\u{1F5C4}\u{1F5D1}-\u{1F5D3}\u{1F5DC}-\u{1F5DE}\u{1F5E1}\u{1F5E3}\u{1F5EF}\u{1F5F3}\u{1F5FA}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CB}-\u{1F6D0}\u{1F6E0}-\u{1F6E5}\u{1F6E9}\u{1F6EB}-\u{1F6EC}\u{1F6F0}\u{1F6F3}\u{1F910}-\u{1F918}\u{1F980}-\u{1F984}\u{1F9C0}][A-Za-z_$0-9]*)/

  def self.sentences # 文列(block) = 文(文)*
    result = [:block]
    while s = GarnetSyntax.sentence()
      result << s
    end
    self.log "[文列] #{result}"
    result
  end

  def self.sentence # 文 = 代入文|IF文|~~文|{文列}
    token = get_token()
    if token == '{'
      result = GarnetSyntax.sentences()
      # unless KW[get_token()&.to_sym] == :rblock
      #   raise 'RBlockNotFoundException'
      # end
      return result
    end
    unget_token()

    if result = GarnetSyntax.print() # nilが返ると次に行く
      self.log "[print文]#{result}"
      return result
    end
    if result = GarnetSyntax.exit()
      self.log "[exit文]"
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
    # if result = GarnetSyntax.assignment_inverse()
    #   self.log "[代入文]#{result}"
    #   return result
    # end
    if token =~ /\[(.*)\]/
      self.log "[コメント] #{$1}"
      return [:comment, $1]
    end
    return nil
  end

  def self.print # print文 = << 式;
    token = get_token()
    if KW[token.to_s&.to_sym] == :print
      result = GarnetSyntax.expression()
      if KW[get_token().to_s&.to_sym] == :eos
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
    if KW[token.to_s&.to_sym] == :input
      token = get_token()
      self.log "変数名トークン => #{token}"
      if token.is_a? String
        var = token
        if KW[get_token()&.to_sym] == :eos
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

  def self.exit # exit文 => :/
    if KW[get_token().to_s&.to_sym] == :exit
      return [:exit]
    else
      unget_token()
      return nil
    end
  end

  def self.assignment # 代入文 = 変数 <= 式
    token = get_token()
    self.log "変数名トークン => #{token}"
    if token.is_a? String
      var = token.dup
      token = get_token()
      self.log "代入KWトークン => #{token}"
      case KW[token.to_s&.to_sym]
      when :assign
        result = [:assignment, var, GarnetSyntax.expression()]
      else
        self.log "正しくない代入KWです"
        unget_token()
        return nil
      end
      self.log "結果 => #{result}"
      unless KW[get_token()&.to_sym] == :eos
        self.log 'エラー前トークン:' + token.to_s
        raise 'Unex-BeforeEndOfStatement'
      end
      return result
    else
      unget_token()
      return nil
    end
  end

  def self.assignment_inverse # 倒置代入文 = 式 => 変数名
    prev_log = @@scanner_log.dup
    if token = GarnetSyntax.expression()
      exp = token.dup
      token = get_token()
      case KW[token.to_s&.to_sym]
      when :assign_inv
        var = get_token()
        raise 'UnrecognizedVarNameException' unless var.is_a? String
        result = [:assignment, var, exp]
        raise 'Unex-BeforeEndOfStatement' unless KW[get_token()&.to_sym] == :eos
        return result
      else
        self.log "正しくない倒置代入KWです"
        unget_token()
        # @@scanner_log = prev_log.dup
        return nil
      end
    else
      unget_token()
      return nil
    end
  end

  def self.ifst # if文 = 式 ?? 文
    prev_log = @@scanner_log.dup
    if token = GarnetSyntax.expression()
      self.log "判定式 => #{token}"
      var = token
      thenkw = get_token()
      self.log "thenKWトークン => #{thenkw}"
      unless KW[thenkw&.to_sym] == :then
        self.log "正しくないthenKWです"
        # @@scanner_log = prev_log.dup
        unget_token()
        unget_token()
        return nil
      end
      result = [:ifst, token, GarnetSyntax.sentence()]
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

      if KW[token.to_s&.to_sym] == :add
        result = [:add, result, GarnetSyntax.term()]
      elsif KW[token.to_s&.to_sym] == :sub
        result = [:sub, result, GarnetSyntax.term()]
      else
        unget_token()
        break
      end
    end
    self.log "[式]#{result}"
    return result
  end

  def self.term # 項 = Fctr ((‘*’|’/’|’:)’|’%’) Fctr)*
    result = GarnetSyntax.factor()
    while true
      token = get_token()
      unless [:mul, :div, :eql, :ineql, :mod].include? KW[token.to_s&.to_sym]
        unget_token()
        break
      end
      token_sym = :mul if KW[token.to_s&.to_sym] == :mul
      token_sym = :div if KW[token.to_s&.to_sym] == :div
      token_sym = :eql if KW[token.to_s&.to_sym] == :eql
      token_sym = :inqel if KW[token.to_s&.to_sym] == :ineql
      token_sym = :mod if KW[token.to_s&.to_sym] == :mod
      result = [token_sym, result, factor]
    end
    self.log '[項]' + result.to_s
    return result
  end

  def self.factor # 因子 = リテラル | 変数 | (式) | "文字列"
    token = get_token()
    minusflg = 1
    if token == '-'
      minusflg = -1
      token = get_token()
    end
    if token.is_a? Numeric
      self.log "[因子] #{token * minusflg}"
      return token * minusflg
    elsif KW[token.to_s&.to_sym] == :lpar
      result = GarnetSyntax.expression()
      unless KW[get_token()&.to_sym] == :rpar
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

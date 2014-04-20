# -*- coding: utf-8 -*-

module RubyHlLvar
  module Vim
    def self.extract_lvars_from(bufnr)
      with_error_handling do
        source = ::Vim.evaluate("getbufline(#{bufnr}, 1, '$')").join("\n")
        return_to_vim 's:ret', RubyHlLvar::Extractor.new.extract(source).map{|(n,l,c)| [n,l,c+1]}
      end
    end

    def self.return_to_vim(var_name, content)
      ::Vim.command "let #{var_name} = #{content.inspect}"
    end

    def self.with_error_handling
      begin
        yield
      rescue => e
        ::Vim.message e
        e.backtrace.each do|l|
          ::Vim.message l
        end
        raise e
      end
    end
  end
end

require 'ripper'

module RubyHlLvar
  class Extractor
    # source:String -> [ [lvar_name:String, line:Numeric, col:Numeric]... ]
    def extract(source)
      sexp = Ripper.sexp(source)
      extract_from_sexp(sexp)
    end

    def extract_from_sexp(sexp)
      p = SexpMatcher
      _any = p::ANY
      _xs = p::ARRAY_REST

      _1 = p._1
      _2 = p._2
      _3 = p._3
      _4 = p._4

      case sexp
      when m = p.match([:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4])
        # single assignment
        [[m._1, m._2, m._3]] + extract_from_sexp(m._4)
      when m = p.match([:massign, _1, _2])
        # mass assignment
        handle_massign_lhs(m._1) + extract_from_sexp(m._2)
      when m = p.match([:var_ref, [:@ident, _1, [_2, _3]]])
        # local variable reference
        [[m._1, m._2, m._3]]
      when m = p.match([:params, _1, _2, _3, _xs])
        handle_normal_params(m._1) + handle_default_params(m._2) + handle_rest_param(m._3)
      when nil, true, false, Numeric, String, Symbol, []
        []
      else
        if sexp.is_a?(Array) && sexp.size > 0
          if sexp[0].is_a?(Symbol) # some struct
            sexp[1..-1].flat_map {|elm| extract_from_sexp(elm) }
          else
            sexp.flat_map{|elm| extract_from_sexp(elm) }
          end
        else
          puts "WARN: Unsupported AST data: #{sexp.inspect}"
          []
        end
      end
    end

    private
      def handle_massign_lhs(lhs)
        return [] unless lhs
        p = SexpMatcher
        if lhs.size > 0 && lhs[0].is_a?(Symbol)
          lhs = [lhs]
        end
        lhs.flat_map {|expr|
          case expr
          when m = p.match([:@ident, p._1, [p._2, p._3]])
            [[m._1, m._2, m._3]]
          when m = p.match([:mlhs_paren, p._1])
            handle_massign_lhs(m._1)
          when m = p.match([:mlhs_add_star, p._1, p._2])
            handle_massign_lhs(m._1) + handle_massign_lhs([m._2])
          else
            puts "WARN: Unsupported ast item in handle_massign_lhs: #{expr.inspect}"
            []
          end
        }
      end

      def handle_normal_params(list)
        handle_massign_lhs(list)
      end

      def handle_rest_param(rest)
        p = SexpMatcher
        case rest
        when m = p.match([:rest_param, [:@ident, p._1, [p._2, p._3]]])
          [[m._1, m._2, m._3]]
        when nil
          []
        else
          puts "WARN: Unsupported ast item in handle_rest_params: #{rest.inspect}"
          []
        end
      end

      def handle_default_params(list)
        return [] unless list
        p = SexpMatcher
        _any = p::ANY
        list.flat_map {|expr|
          case expr
          when m = p.match([[:@ident, p._1, [p._2, p._3]], _any])
            [[m._1, m._2, m._3]]
          else
            []
          end
        }
      end
  end

  class SexpMatcher
    class SpecialPat
      def execute(match, obj); true; end

      def rest?
        false
      end

      def self.build_from(plain)
        case plain
        when SpecialPat
          plain
        when Array
          if plain.last.is_a?(SpecialPat) && plain.last.rest?
            Arr.new(plain[0..-2].map{|p| build_from(p) }, plain.last)
          else
            Arr.new(plain.map{|p| build_from(p) })
          end
        else
          Obj.new(plain)
        end
      end

      def &(rhs)
        And.new([self, rhs])
      end

      class Arr < self
        def initialize(head, rest = nil, tail = [])
          @head = head
          @rest = rest
          @tail = tail
        end

        def execute(mmatch, obj)
          size_min = @head.size + @tail.size
          return false unless obj.is_a?(Array)
          return false unless @rest ? (obj.size >= size_min) :  (obj.size == size_min)
          @head.zip(obj[0..(@head.size - 1)]).all? {|pat, o|
            pat.execute(mmatch, o)
          } &&
          @tail.zip(obj[(-@tail.size)..-1]).all? {|pat, o|
            pat.execute(mmatch, o)
          } &&
          (!@rest || @rest.execute(mmatch, obj[@head.size..-(@tail.size+1)]))
        end
      end

      class ArrRest < self
        def execute(mmatch, obj)
          true
        end
        def rest?
          true
        end
      end

      class Obj < self
        def initialize(obj)
          @obj = obj
        end

        def execute(mmatch, obj)
          @obj == obj
        end
      end

      class Any < self
        def execute(match, obj); true; end
      end

      class Group < self
        def initialize(index)
          @index = index
        end
        attr_reader :index
        def execute(mmatch, obj)
          mmatch[@index] = obj
          true
        end
      end

      class Or < self
        def initialize(pats)
          @pats = pats
        end
        def execute(mmatch, obj)
          @pats.any? do|pat|
            pat.execute(mmatch, obj)
          end
        end
        def rest?
          @pats.any?(&rest?)
        end
      end

      class And <self
        def initialize(pats)
          @pats = pats
        end
        def execute(mmatch, obj)
          @pats.all? do|pat|
            pat.execute(mmatch, obj)
          end
        end
        def rest?
          @pats.any?(&:rest?)
        end
      end
    end

    ANY = SpecialPat::Any.new
    GROUP = 100.times.map{|i| SpecialPat::Group.new(i) }
    ARRAY_REST = SpecialPat::ArrRest.new

    class MutableMatch
      def initialize(pat)
        @pat = pat
        @group = {}
      end

      def ===(obj)
        @pat.execute(self, obj)
      end

      def [](i)
        @group[i]
      end

      def []=(i, val)
        @group[i] = val
      end

      SexpMatcher::GROUP.each do|g|
        define_method "_#{g.index}" do
          self[g.index]
        end
      end
    end

    def self.match(plain_pat)
      MutableMatch.new(SpecialPat.build_from(plain_pat))
    end

    def self.match_array(head, rest_spat = nil, tail = [])
      MutableMatch.new(
        SpecialPat::Arr.new(
          head.map{|e| SpecialPat.build_from(e)},
          rest_spat,
          tail.map{|e| SpecialPat.build_from(e)}
        )
      )
    end

    def self.or(*pats)
      SpecialPat::Or.new(pats.map{|p| SpecialPat.build_from(p) })
    end

    class <<self
      GROUP.each do|g|
        define_method "_#{g.index}" do
          g
        end
      end
    end

  end
end

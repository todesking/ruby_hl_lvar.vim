require File.join(File.dirname(__FILE__), '..', 'vendor', 'patm', 'lib', 'patm.rb')

module RubyHlLvar
  class Extractor
    extend ::Patm::DSL

    def initialize(show_warning = false)
      @show_warning = show_warning
    end

    def warn(message)
      ::Vim.message "[ruby_hl_lvar.vim] WARN: #{message}" if @show_warning
    end

    # source:String -> [ [lvar_name:String, line:Numeric, col:Numeric]... ]
    def extract(source)
      sexp = Ripper.sexp(source)
      extract_from_sexp(sexp)
    end

    define_matcher :extract_from_sexp do|r|
      p = Patm
      __ = p._any
      _xs = p._xs

      l_1 = p._1
      l_2 = p._2
      l_3 = p._3
      l_4 = p._4
      l_5 = p._5
      l_6 = p._6

      # single assignment
      r.on [:assign, [:var_field, [:@ident, l_1, [l_2, l_3]]], l_4] do|m, _self|
        [[m._1, m._2, m._3]] + _self.extract_from_sexp(m._4)
      end
      # mass assignment
      r.on [:massign, l_1, l_2] do|m, _self|
        _self.handle_massign_lhs(m._1) + _self.extract_from_sexp(m._2)
      end
      # +=
      r.on [:opassign, [:var_field, [:@ident, l_1, [l_2, l_3]]], __, l_4] do|m, _self|
        [[m._1, m._2, m._3]] + _self.extract_from_sexp(m._4)
      end
      # local variable reference
      r.on [:var_ref, [:@ident, l_1, [l_2, l_3]]] do|m|
        [[m._1, m._2, m._3]]
      end
      # rescue
      r.on [:rescue, l_1, [:var_field, [:@ident, l_2, [l_3, l_4]]], l_5, l_6] do|m, _self|
        [[m._2, m._3, m._4]] + _self.extract_from_sexp(m._1) + _self.extract_from_sexp(m._5) + _self.extract_from_sexp(m._6)
      end
      # method params
      r.on [:params, _xs&l_1] do|m, _self|
        _self.handle_normal_params(m._1[0]) +
          _self.handle_default_params(m._1[1]) +
          _self.handle_rest_param(m._1[2]) +
          _self.handle_normal_params(m._1[3]) +
          _self.handle_block_param(m._1[6])
      end
      # for
      r.on [:for, l_1, l_2, l_3] do|m, _self|
        _self.handle_for_param(m._1) + _self.extract_from_sexp(m._2) + _self.extract_from_sexp(m._3)
      end
      r.on p.or(nil, true, false, Numeric, String, Symbol, []) do|m|
        []
      end
      r.else do|sexp, _self|
        if sexp.is_a?(Array) && sexp.size > 0
          if sexp[0].is_a?(Symbol) # some struct
            sexp[1..-1].flat_map {|elm| _self.extract_from_sexp(elm) }
          else
            sexp.flat_map{|elm| _self.extract_from_sexp(elm) }
          end
        else
          _self.warn "Unsupported AST data: #{sexp.inspect}"
          []
        end
      end
    end

    define_matcher :handle_massign_lhs_item do|r|
      p = Patm
      r.on [:var_field, [:@ident, p._1, [p._2, p._3]]] do|m|
        [[m._1, m._2, m._3]]
      end
      r.on [:@ident, p._1, [p._2, p._3]] do|m|
        [[m._1, m._2, m._3]]
      end
      r.on [:mlhs, p._xs[:xs]] do|m, _self|
        m[:xs].inject([]) {|lhss, l| lhss + _self.handle_massign_lhs(l) }
      end
      r.on [:aref_field, p._1, p._2] do |m, _self|
        _self.extract_from_sexp(m._1) + _self.extract_from_sexp(m._2)
      end
      r.on [p.or(:field, :@ivar, :@cvar, :@gvar, :@const), p._xs] do
        []
      end
      r.on [:rest_param, p._1] do|m, _self|
        _self.handle_massign_lhs_item(m._1)
      end
      r.on nil do
        []
      end
      r.else do|obj, _self|
        _self.warn "Unsupported ast item in handle_massign_lhs: #{obj.inspect}"
        []
      end
    end

    def handle_massign_lhs(lhs)
      return [] unless lhs
      if lhs.size > 0 && lhs[0].is_a?(Symbol)
        lhs = [lhs]
      end
      lhs.flat_map {|expr| handle_massign_lhs_item(expr) }
    end

    def handle_normal_params(list)
      handle_massign_lhs(list)
    end

    define_matcher :handle_rest_param do|r, _self|
      p = Patm
      r.on [:rest_param, [:@ident, p._1, [p._2, p._3]]] do|m|
        [[m._1, m._2, m._3]]
      end
      r.on nil do
        []
      end
      r.on 0 do
        []
      end
      r.on [:rest_param, nil] do
        []
      end
      r.else do|obj, _self|
        _self.warn "Unsupported ast item in handle_rest_params: #{obj.inspect}"
        []
      end
    end

    define_matcher :handle_block_param do|r|
      p = ::Patm
      r.on [:blockarg, [:@ident, p._1, [p._2, p._3]]] do|m|
        [[m._1, m._2, m._3]]
      end
      r.on nil do
        []
      end
      r.else do|obj, _self|
        _self.warn "Unsupported ast item in handle_block_params: #{obj.inspect}"
        []
      end
    end

    def handle_default_params(list)
      return [] unless list
      list.flat_map {|expr| handle_default_param(expr) }
    end

    define_matcher :handle_default_param do|r|
      p = Patm
      r.on [[:@ident, p._1, [p._2, p._3]], p._any] do|m|
        [[m._1, m._2, m._3]]
      end
      r.else do
        []
      end
    end

    define_matcher :handle_for_param do|r|
      p = Patm
      r.on [:var_field, [:@ident, p._1, [p._2, p._3]]] do|m, _self|
        [[m._1, m._2, m._3]]
      end
      r.on [:var_field, p._xs] do|m, _self|
        []
      end
      r.else do|sexp, _self|
        _self.handle_massign_lhs(sexp)
      end
    end
  end
end

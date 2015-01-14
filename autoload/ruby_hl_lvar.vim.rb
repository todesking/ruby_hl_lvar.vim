# -*- coding: utf-8 -*-
require 'ripper'
require File.join(File.dirname(__FILE__), '..', 'vendor', 'patm', 'lib', 'patm.rb')

def Vim.message(msg)
  # ::Vim.message and ::Kernel.puts seems weird behavior
  ::Vim.command("echo '#{msg.gsub(/'/, "''")}'")
end

module RubyHlLvar
  module Vim
    def self.extract_lvars_from(bufnr)
      with_error_handling do
        source = ::Vim.evaluate("getbufline(#{bufnr}, 1, '$')").join("\n")
        show_warnings = ::Vim.evaluate("g:ruby_hl_lvar_show_warnings") != 0
        return_to_vim 's:ret', RubyHlLvar::Extractor.new(show_warnings).extract(source).map{|(n,l,c)| [n,l,c+1]}
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

      _1 = p._1
      _2 = p._2
      _3 = p._3
      _4 = p._4

      # single assignment
      r.on [:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4] do|m, _self|
        [[m._1, m._2, m._3]] + _self.extract_from_sexp(m._4)
      end
      # mass assignment
      r.on [:massign, _1, _2] do|m, _self|
        _self.handle_massign_lhs(m._1) + _self.extract_from_sexp(m._2)
      end
      # +=
      r.on [:opassign, [:var_field, [:@ident, _1, [_2, _3]]], __, _4] do|m, _self|
        [[m._1, m._2, m._3]] + _self.extract_from_sexp(m._4)
      end
      # local variable reference
      r.on [:var_ref, [:@ident, _1, [_2, _3]]] do|m|
        [[m._1, m._2, m._3]]
      end
      # method params
      r.on [:params, _xs&_1] do|m, _self|
        _self.handle_normal_params(m._1[0]) +
          _self.handle_default_params(m._1[1]) +
          _self.handle_rest_param(m._1[2]) +
          _self.handle_block_param(m._1[6])
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
          warn "Unsupported AST data: #{sexp.inspect}"
          []
        end
      end
    end

    define_matcher :handle_massign_lhs_item do|r|
      p = Patm
      r.on [:@ident, p._1, [p._2, p._3]] do|m|
        [[m._1, m._2, m._3]]
      end
      r.on [:mlhs_paren, p._1] do|m, _self|
        _self.handle_massign_lhs(m._1)
      end
      r.on [:mlhs_add_star, p._1, p._2] do|m, _self|
        _self.handle_massign_lhs(m._1) + _self.handle_massign_lhs([m._2])
      end
      r.on [:field, p._xs] do
        []
      end
      r.on [:@ivar, p._xs] do
        []
      end
      r.else do|obj|
        warn "Unsupported ast item in handle_massign_lhs: #{obj.inspect}"
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
      r.else do|obj|
        warn "Unsupported ast item in handle_rest_params: #{obj.inspect}"
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
      r.else do|obj|
        warn "Unsupported ast item in handle_block_params: #{obj.inspect}"
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
  end
end

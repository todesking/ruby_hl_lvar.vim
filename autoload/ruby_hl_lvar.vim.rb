# -*- coding: utf-8 -*-
require 'ripper'
require File.join(File.dirname(__FILE__), '..', 'vendor', 'patm', 'lib', 'patm.rb')

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

module RubyHlLvar
  class Extractor
    def initialize
      # rule_name => Patm::Rule
      @rules = {}
    end
    # source:String -> [ [lvar_name:String, line:Numeric, col:Numeric]... ]
    def extract(source)
      sexp = Ripper.sexp(source)
      extract_from_sexp(sexp)
    end

    def root_matcher
      @root_matcher ||= begin
        p = Patm
        _any = p::ANY
        _xs = p::ARRAY_REST

        _1 = p._1
        _2 = p._2
        _3 = p._3
        _4 = p._4

        ::Patm::Rule.new do|r|
          # single assignment
          r.on [:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4] do|m|
            [[m._1, m._2, m._3]] + extract_from_sexp(m._4)
          end
          # mass assignment
          r.on [:massign, _1, _2] do|m|
            handle_massign_lhs(m._1) + extract_from_sexp(m._2)
          end
          # local variable reference
          r.on [:var_ref, [:@ident, _1, [_2, _3]]] do|m|
            [[m._1, m._2, m._3]]
          end
          # method params
          r.on [:params, _1, _2, _3, _xs] do|m|
            handle_normal_params(m._1) + handle_default_params(m._2) + handle_rest_param(m._3)
          end
          r.on p.or(nil, true, false, Numeric, String, Symbol, []) do|m|
            []
          end
          r.else do|sexp|
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
      end
    end

    def extract_from_sexp(obj)
      match(:root, obj) do|r|
        p = Patm
        __ = p::ANY
        _xs = p::ARRAY_REST

        _1 = p._1
        _2 = p._2
        _3 = p._3
        _4 = p._4

        # single assignment
        r.on [:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4] do|m|
          [[m._1, m._2, m._3]] + extract_from_sexp(m._4)
        end
        # mass assignment
        r.on [:massign, _1, _2] do|m|
          handle_massign_lhs(m._1) + extract_from_sexp(m._2)
        end
        # local variable reference
        r.on [:var_ref, [:@ident, _1, [_2, _3]]] do|m|
          [[m._1, m._2, m._3]]
        end
        # method params
        r.on [:params, _xs&_1] do|m|
          handle_normal_params(m._1[0]) +
            handle_default_params(m._1[1]) +
            handle_rest_param(m._1[2]) +
            handle_block_param(m._1[6])
        end
        r.on p.or(nil, true, false, Numeric, String, Symbol, []) do|m|
          []
        end
        r.else do|sexp|
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
    end

    private
      def match(rule_name, obj, &rule)
        (@rules[rule_name] ||= ::Patm::Rule.new(&rule)).apply(obj)
      end
      def handle_massign_lhs(lhs)
        return [] unless lhs
        if lhs.size > 0 && lhs[0].is_a?(Symbol)
          lhs = [lhs]
        end
        lhs.flat_map {|expr|
          match(:massign_lhs_item, expr) do|r|
            p = Patm
            r.on [:@ident, p._1, [p._2, p._3]] do|m|
              [[m._1, m._2, m._3]]
            end
            r.on [:mlhs_paren, p._1] do|m|
              handle_massign_lhs(m._1)
            end
            r.on [:mlhs_add_star, p._1, p._2] do|m|
              handle_massign_lhs(m._1) + handle_massign_lhs([m._2])
            end
            r.on [:field, p::ARRAY_REST] do
              []
            end
            r.on [:@ivar, p::ARRAY_REST] do
              []
            end
            r.else do|obj|
              puts "WARN: Unsupported ast item in handle_massign_lhs: #{obj.inspect}"
              []
            end
          end
        }
      end

      def handle_normal_params(list)
        handle_massign_lhs(list)
      end

      def handle_rest_param(rest)
        match(:rest_param, rest) do|r|
          p = Patm
          r.on [:rest_param, [:@ident, p._1, [p._2, p._3]]] do|m|
            [[m._1, m._2, m._3]]
          end
          r.on nil do
            []
          end
          r.else do|obj|
            puts "WARN: Unsupported ast item in handle_rest_params: #{obj.inspect}"
            []
          end
        end
      end

      def handle_block_param(block)
        match(:block_param, block) do|r|
          p = ::Patm
          r.on [:blockarg, [:@ident, p._1, [p._2, p._3]]] do|m|
            [[m._1, m._2, m._3]]
          end
          r.on nil do
            []
          end
          r.else do|obj|
            puts "WARN: Unsupported ast item in handle_block_params: #{obj.inspect}"
            []
          end
        end
      end

      def handle_default_params(list)
        return [] unless list
        p = Patm
        _any = p::ANY
        list.flat_map {|expr|
          match(:default_param, expr) do|r|
            r.on [[:@ident, p._1, [p._2, p._3]], _any] do|m|
              [[m._1, m._2, m._3]]
            end
            r.else do
              []
            end
          end
        }
      end
  end
end

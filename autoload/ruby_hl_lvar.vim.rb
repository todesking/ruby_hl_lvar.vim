# -*- coding: utf-8 -*-
require 'ripper'

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

if Gem::Version.create(RUBY_VERSION) < Gem::Version.create('2.5.0')
  require File.join(File.dirname(__FILE__), 'extractor_240.rb')
else
  require File.join(File.dirname(__FILE__), 'extractor_250.rb')
end

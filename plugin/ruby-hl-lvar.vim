""; <<-finish
finish

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

      case sexp
      when m = p.match([:program, p._1])
        m[1].flat_map {|subtree| extract_from_sexp(subtree) }
      when m = p.match([:assign, [:var_field, [:@ident, p._1, p._2]], _any])
        name, (line, col) = m._1, m._2
        [[name, line, col]]
      else
        []
      end
    end
  end

  class SexpMatcher
    class SpecialPat
      def initialize(name)
        @name = name
      end
      def execute(match, obj); true; end

      class Any < self
        def initialize(); super('*'); end
        def execute(match, obj); true; end
      end

      class Group < self
        def initialize(index)
          super("_#{index}")
          @index = index
        end
        attr_reader :index
        def execute(mmatch, obj)
          mmatch[@index] = obj
          true
        end
      end
    end

    ANY = SpecialPat::Any.new
    GROUP = 100.times.map{|i| SpecialPat::Group.new(i) }

    class MutableMatch
      def initialize(pat)
        @pat = pat
        @group = {}
      end

      def ===(obj)
        _match(@pat, obj)
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

      private
        def _match(pat, obj)
          case pat
          when SpecialPat
            pat.execute(self, obj)
          when Array
            Array === obj &&
              pat.size == obj.size &&
              pat.zip(obj).all? {|p,o| _match(p, o) }
          when Hash
            raise "Not implemented now :("
          else
            pat == obj
          end
        end
    end

    def self.match(pat)
      MutableMatch.new(pat)
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


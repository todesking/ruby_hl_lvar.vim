module Patm
  class Pattern
    def execute(match, obj); true; end

    def rest?
      false
    end

    def self.build_from(plain)
      case plain
      when Pattern
        plain
      when Array
        if plain.last.is_a?(Pattern) && plain.last.rest?
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
        @obj === obj
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

  ANY = Pattern::Any.new
  GROUP = 100.times.map{|i| Pattern::Group.new(i) }
  ARRAY_REST = Pattern::ArrRest.new

  class Rule
    def initialize(&block)
      # { Pattern => Proc }
      @rules = []
      block[self]
    end

    def on(pat, &block)
      @rules << [Pattern.build_from(pat), block]
    end

    def else(&block)
      @rules << [ANY, lambda {|m,o| block[o] }]
    end

    def apply(obj)
      match = Match.new
      @rules.each do|(pat, block)|
        if pat.execute(match, obj)
          return block.call(match, obj)
        end
      end
      nil
    end
  end

  class RuleCache
    def initialize
      @rules = {}
    end
    def match(rule_name, obj, &rule)
      (@rules[rule_name] ||= ::Patm::Rule.new(&rule)).apply(obj)
    end
  end

  class Match
    def initialize
      @group = {}
    end

    def [](i)
      @group[i]
    end

    def []=(i, val)
      @group[i] = val
    end

    Patm::GROUP.each do|g|
      define_method "_#{g.index}" do
        self[g.index]
      end
    end
  end

  class CaseBinder
    def initialize(pat)
      @pat = pat
      @match = Match.new
    end

    def ===(obj)
      @pat.execute(@match, obj)
    end

    def [](i); @match[i]; end
    Patm::GROUP.each do|g|
      define_method "_#{g.index}" do
        @match[g.index]
      end
    end
  end

  def self.match(plain_pat)
    CaseBinder.new Pattern.build_from(plain_pat)
  end

  def self.match_array(head, rest_spat = nil, tail = [])
    Match.new(
      Pattern::Arr.new(
        head.map{|e| Pattern.build_from(e)},
        rest_spat,
        tail.map{|e| Pattern.build_from(e)}
      )
    )
  end

  def self.or(*pats)
    Pattern::Or.new(pats.map{|p| Pattern.build_from(p) })
  end

  class <<self
    GROUP.each do|g|
      define_method "_#{g.index}" do
        g
      end
    end
  end
end

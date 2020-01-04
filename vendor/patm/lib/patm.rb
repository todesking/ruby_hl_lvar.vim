module Patm
  class NoMatchError < StandardError
    def initialize(value)
      super("Pattern not match: value=#{value.inspect}")
      @value = value
    end
    attr_reader :value
  end
  class Pattern

    def self.build_from(plain)
      case plain
      when Pattern
        plain
      when ::Array
        build_from_array(plain)
      when ::Hash
        build_from_hash(plain)
      else
        Obj.new(plain)
      end
    end

    def self.build_from_array(plain)
      array = plain.map{|a| build_from(a)}
      rest_index = array.index(&:rest?)
      if rest_index
        head = array[0...rest_index]
        rest = array[rest_index]
        tail = array[(rest_index+1)..-1]
        Arr.new(head, rest, tail)
      else
        Arr.new(array)
      end
    end

    def self.build_from_hash(plain)
      self::Hash.new(
        plain.each_with_object({}) do|(k, v), h|
          h[k] = build_from(v) if k != Patm.exact
        end,
        plain[Patm.exact]
      )
    end

    module Util
      def self.compile_value(value, free_index)
        if value.nil? || value.is_a?(Numeric) || value.is_a?(String) || value.is_a?(Symbol)
          [
            value.inspect,
            [],
            free_index,
          ]
        else
          [
            "_ctx[#{free_index}]",
            [value],
            free_index + 1,
          ]
        end
      end
    end

    # Use in Hash pattern.
    def opt
      Opt.new(self)
    end

    def execute(match, obj); true; end

    def opt?
      false
    end

    def rest?
      false
    end

    def &(rhs)
      And.new([self, Pattern.build_from(rhs)])
    end

    def [](name)
      self & Named.new(name)
    end

    def compile
      src, context, _ = self.compile_internal(0)

      Compiled.new(self.inspect, src || "true", context)
    end

    # free_index:Numeric -> target_name:String -> [src:String|nil, context:Array, free_index:Numeric]
    # variables: _ctx, _match, (target_name)
    def compile_internal(free_index, target_name = "_obj")
      [
        "_ctx[#{free_index}].execute(_match, #{target_name})",
        [self],
        free_index + 1
      ]
    end

    class Compiled < self
      def initialize(desc, src, context)
        @desc = desc
        @context = context
        singleton_class = class <<self; self; end
        @src_body = src
        @src = <<-RUBY
        def execute(_match, _obj)
          _ctx = @context
#{src}
        end
        RUBY
        singleton_class.class_eval(@src)
      end

      attr_reader :src_body
      attr_reader :src

      def compile_internal(free_index, target_name = "_obj")
        raise "already compiled"
      end
      def inspect; "<compiled>#{@desc}"; end
    end

    class Hash < self
      def initialize(hash, exact)
        @pat = hash
        @exact = exact
        @non_opt_count = @pat.values.count{|v| !v.opt? }
      end
      def execute(match, obj)
        return false unless obj.is_a?(::Hash)
        obj.size >= @non_opt_count &&
          (!@exact || obj.keys.all?{|k| @pat.has_key?(k) }) &&
          @pat.all? {|k, pat|
            if obj.has_key?(k)
              pat.execute(match, obj[k])
            else
              pat.opt?
            end
          }
      end
      def inspect; @pat.inspect; end
      def compile_internal(free_index, target_name = "_obj")
        i = free_index
        ctxs = []
        src = []

        ctxs << [@pat]
        i += 1

        pat = "_ctx[#{free_index}]"
        src << "#{target_name}.is_a?(::Hash)"
        src << "#{target_name}.size >= #{@non_opt_count}"
        if @exact
          src << "#{target_name}.keys.all?{|k| #{pat}.has_key?(k) }"
        end
        tname = "#{target_name}_elm"
        @pat.each do|k, v|
          key_src, c, i = Util.compile_value(k, i)
          ctxs << c
          s, c, i = v.compile_internal(i, tname)
          body =
            if s
              "(#{tname} = #{target_name}[#{key_src}]; #{s})"
            else
              "true"
            end
          src <<
            if v.opt?
              "(!#{target_name}.has_key?(#{key_src}) || #{body})"
            else
              "(#{target_name}.has_key?(#{key_src}) && #{body})"
            end
          ctxs << c
        end
        [
          src.join(" &&\n"),
          ctxs.flatten(1),
          i,
        ]
      end
    end

    class Opt < self
      def initialize(pat)
        @pat = pat
      end
      def opt?
        true
      end
      def execute(match, obj)
        @pat.execute(match, obj)
      end
      def inspect; "?#{@pat.inspect}"; end
      def compile_internal(free_index, target_name = "_obj")
        @pat.compile_internal(free_index, target_name)
      end
    end

    class Arr < self
      def initialize(head, rest = nil, tail = [])
        @head = head
        @rest = rest
        @tail = tail
      end

      def execute(mmatch, obj)
        return false unless obj.is_a?(Array)

        size_min = @head.size + @tail.size
        if @rest
          return false if obj.size < size_min
        else
          return false if obj.size != size_min
        end

        return false unless @head.zip(obj[0..(@head.size - 1)]).all? {|pat, o|
          pat.execute(mmatch, o)
        }

        return false unless @tail.zip(obj[(-@tail.size)..-1]).all? {|pat, o|
          pat.execute(mmatch, o)
        }

        !@rest || @rest.execute(mmatch, obj[@head.size..-(@tail.size+1)])
      end

      def inspect
        if @rest
          (@head + [@rest] + @tail).inspect
        else
          (@head + @tail).inspect
        end
      end

      def compile_internal(free_index, target_name = "_obj")
        i = free_index
        srcs = []
        ctxs = []

        srcs << "#{target_name}.is_a?(::Array)"

        i = compile_size_check(target_name, srcs, ctxs, i)

        i = compile_part(target_name, @head, srcs, ctxs, i)

        unless @tail.empty?
          srcs << "#{target_name}_t = #{target_name}[(-#{@tail.size})..-1]; true"
          i = compile_part("#{target_name}_t", @tail, srcs, ctxs, i)
        end

        i = compile_rest(target_name, srcs, ctxs, i)

        [
          srcs.compact.map{|s| "(#{s})"}.join(" &&\n"),
          ctxs.flatten(1),
          i
        ]
      end

      private
        def compile_size_check(target_name, srcs, ctxs, i)
          size_min = @head.size + @tail.size
          if @rest
            srcs << "#{target_name}.size >= #{size_min}"
          else
            srcs << "#{target_name}.size == #{size_min}"
          end
          i
        end

        def compile_part(target_name, part, srcs, ctxs, i)
          part.each_with_index do|h, hi|
            if h.is_a?(Obj)
              s, c, i = h.compile_internal(i, "#{target_name}[#{hi}]")
              srcs << "#{s}" if s
              ctxs << c
            else
              elm_target_name = "#{target_name}_elm"
              s, c, i = h.compile_internal(i, elm_target_name)
              srcs << "#{elm_target_name} = #{target_name}[#{hi}]; #{s}" if s
              ctxs << c
            end
          end
          i
        end

        def compile_rest(target_name, srcs, ctxs, i)
          return i unless @rest
          tname = "#{target_name}_r"
          s, c, i = @rest.compile_internal(i, tname)
          srcs << "#{tname} = #{target_name}[#{@head.size}..-(#{@tail.size+1})];#{s}" if s
          ctxs << c
          i
        end
    end

    class ArrRest < self
      def execute(mmatch, obj)
        true
      end
      def rest?
        true
      end
      def inspect; "..."; end
      def compile_internal(free_index, target_name = "_obj")
        [
          nil,
          [],
          free_index
        ]
      end
    end

    class Obj < self
      def initialize(obj)
        @obj = obj
      end

      def execute(mmatch, obj)
        @obj === obj
      end

      def inspect
        "OBJ(#{@obj.inspect})"
      end

      def compile_internal(free_index, target_name = "_obj")
        val_src, c, i = Util.compile_value(@obj, free_index)
        [
          "#{val_src} === #{target_name}",
          c,
          i
        ]
      end
    end

    class Any < self
      def execute(match, obj); true; end
      def inspect; 'ANY'; end
      def compile_internal(free_index, target_name = "_obj")
        [
          nil,
          [],
          free_index
        ]
      end
    end

    class Struct < self
      def initialize(klass, pat)
        @klass, @pat = klass, pat
      end

      def inspect
        "STRUCT(#{@klass.name || "<unnamed>"}, #{@pat.inspect})"
      end

      def execute(match, obj)
        obj.is_a?(@klass) && @pat.all?{|k, v| v.execute(match, obj[k]) }
      end

      def compile_internal(free_index, target_name = "_obj")
        srcs = []
        ctxs = []
        i = free_index

        if @klass.name
          srcs << "#{target_name}.is_a?(::#{@klass.name})"
        else
          srcs << "#{target_name}.is_a?(_ctx[#{i}])"
          ctxs << [@klass]
          i += 1
        end

        @pat.each do|(member, v)|
          s, c, i = v.compile_internal(i, "#{target_name}_elm")
          srcs << "#{target_name}_elm = #{target_name}.#{member}; #{s}" if s
          ctxs << c
        end

        [
          srcs.map{|s| "(#{s})"}.join(" &&\n"),
          ctxs.flatten(1),
          i
        ]
      end

      class Builder
        def initialize(klass)
          raise ArgumentError, "#{klass} is not Struct" unless klass.ancestors.include?(::Struct)
          @klass = klass
        end

        # member_1_pat -> member_2_pat -> ... -> Pattern
        # {member:Symbol => pattern} -> Pattern
        def call(*args)
          if args.size == 1 && args.first.is_a?(::Hash)
            hash = args.first
            hash.keys.each do|k|
              raise ArgumentError, "#{k.inspect} is not member of #{@klass}" unless @klass.members.include?(k)
            end
            Struct.new(@klass, hash.each_with_object({}){|(k, plain), h|
              h[k] = Pattern.build_from(plain)
            })
          else
            raise ArgumentError, "Member size not match: expected #{@klass.members.size} but #{args.size}" unless args.size == @klass.members.size
            Struct.new(@klass, ::Hash[*@klass.members.zip(args.map{|a| Pattern.build_from(a) }).flatten(1)])
          end
        end
      end
    end

    class Named < self
      def initialize(name)
        raise ::ArgumentError unless name.is_a?(Symbol) || name.is_a?(Numeric)
        @name = name
      end
      attr_reader :name
      alias index name # compatibility
      def execute(match, obj)
        match[@name] = obj
        true
      end
      def inspect; "NAMED(#{@name})"; end
      def compile_internal(free_index, target_name = "_obj")
        [
          "_match[#{@name.inspect}] = #{target_name}; true",
          [],
          free_index
        ]
      end
    end

    class LogicalOp < self
      def initialize(name, pats, op_str)
        @name = name
        @pats = pats
        @op_str = op_str
      end
      def compile_internal(free_index, target_name = "_obj")
        srcs = []
        i = free_index
        ctxs = []
        @pats.each do|pat|
          s, c, i = pat.compile_internal(i, target_name)
          if !s && @op_str == '||' # dirty...
            srcs << 'true'
          else
            srcs << s
          end
          ctxs << c
        end

        [
          srcs.compact.map{|s| "(#{s})" }.join(" #{@op_str}\n"),
          ctxs.flatten(1),
          i
        ]
      end
      def rest?
        @pats.any?(&:rest?)
      end
      def opt?
        @pats.any?(&:opt?)
      end
      def inspect
        "#{@name}(#{@pats.map(&:inspect).join(',')})"
      end
    end

    class Or < LogicalOp
      def initialize(pats)
        super('OR', pats, '||')
      end
      def execute(mmatch, obj)
        @pats.any? do|pat|
          pat.execute(mmatch, obj)
        end
      end
    end

    class And < LogicalOp
      def initialize(pats)
        super('AND', pats, '&&')
      end
      def execute(mmatch, obj)
        @pats.all? do|pat|
          pat.execute(mmatch, obj)
        end
      end
    end
  end

  def self.or(*pats)
    Pattern::Or.new(pats.map{|p| Pattern.build_from(p) })
  end

  def self._any
    @any ||= Pattern::Any.new
  end

  def self._xs
    @xs = Pattern::ArrRest.new
  end

  # Use in hash value.
  # Mark this pattern is optional.
  def self.opt(pat = _any)
    Pattern::Opt.new(Pattern.build_from(pat))
  end

  EXACT = Object.new
  def EXACT.inspect
    "EXACT"
  end
  # Use in Hash key.
  # Specify exact match or not.
  def self.exact
    EXACT
  end

  def self.[](struct_klass)
    Pattern::Struct::Builder.new(struct_klass)
  end

  PREDEF_GROUP_SIZE = 100

  class <<self
    PREDEF_GROUP_SIZE.times do|i|
      define_method "_#{i}" do
        Pattern::Named.new(i)
      end
    end
  end

  def self.match(plain_pat)
    CaseBinder.new Pattern.build_from(plain_pat)
  end

  class Rule
    def initialize(&block)
      # [[Pattern, Proc]...]
      @rules = []
      @else = nil
      block[self]
    end

    def on(pat, &block)
      @rules << [Pattern.build_from(pat), block]
    end

    def else(&block)
      @else = block
    end

    def apply(obj, _self = nil)
      match = Match.new
      @rules.each do|(pat, block)|
        if pat.execute(match, obj)
          return block.call(match, _self)
        end
      end
      @else ? @else[obj, _self] : (raise NoMatchError.new(obj))
    end

    def inspect
      "Rule{#{@rules.map(&:first).map(&:inspect).join(', ')}#{@else ? ', _' : ''}}"
    end

    def compile_call(block, *args)
      "call(#{args[0...block.arity].join(', ')})"
    end

    def compile
      i = 0
      ctxs = []
      srcs = []
      @rules.each do|pat, block|
        s, c, i = pat.compile_internal(i, '_obj')
        ctxs << c
        ctxs << [block]
        srcs << "if (#{s || 'true'})\n_ctx[#{i}].#{compile_call(block, "::Patm::Match.new(_match)"," _self")}"
        i += 1
      end
      src = srcs.join("\nels")
      if @else
        src << "\nelse\n" unless srcs.empty?
        src << "_ctx[#{i}].#{compile_call(@else, "_obj"," _self")}"
        ctxs << [@else]
        i += 1
      else
        src << "\nelse\n" unless srcs.empty?
        src << "raise ::Patm::NoMatchError.new(_obj)"
      end
      src << "\nend" unless srcs.empty?
      Compiled.new(
        src,
        ctxs.flatten(1)
      )
    end

    class Compiled
      def initialize(src_body, context)
        @src_body = src_body
        @context = context
        @src = <<-RUBY
        def apply(_obj, _self = nil)
          _ctx = @context
          _match = {}
#{@src_body}
        end
        RUBY

        singleton_class = class <<self; self; end
        singleton_class.class_eval(@src)
      end

      attr_reader :src_body
      attr_reader :context
    end
  end

  class Match
    def initialize(data = {})
      @data = data
    end

    def [](i)
      @data[i]
    end

    def []=(i, val)
      @data[i] = val
    end

    PREDEF_GROUP_SIZE.times.each do|i|
      define_method "_#{i}" do
        @data[i]
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
    PREDEF_GROUP_SIZE.times do|i|
      define_method "_#{i}" do
        @match[i]
      end
    end
  end

  module DSL
    def define_matcher(name, &rule)
      rule = Rule.new(&rule).compile
      ctx = rule.context
      self.class_variable_set("@@_patm_ctx_#{name}", ctx)
      src = <<-RUBY
      def #{name}(_obj)
        _self = self
        _ctx = self.#{self.name ? 'class' : 'singleton_class'}.class_variable_get(:@@_patm_ctx_#{name})
        _match = {}
#{rule.src_body}
      end
      RUBY
      class_eval(src)
    end
  end
end

require 'simplecov'
require 'simplecov-vim/formatter'
SimpleCov.start do
  formatter SimpleCov::Formatter::VimFormatter
  formatter SimpleCov::Formatter::HTMLFormatter
end

require File.join(File.dirname(__FILE__), '..', 'lib', 'patm.rb')
require 'pry'

module PatmHelper
  module Pattern
    extend RSpec::Matchers::DSL

    matcher :these_matches do|*matches|
      match do|actual|
        matches.all?{|m| m.matches?(actual) }
      end
    end

    matcher :match_to do|expected|
      match do|actual|
        exec(actual, expected)
      end

      def exec(actual, expected)
        @match = Patm::Match.new
        actual.execute(@match, expected)
      end

      def match; @match; end

      def and_capture(g1, g2 = nil, g3 = nil, g4 = nil)
        these_matches(
          self, _capture(self, {1 => g1, 2 => g2, 3 => g3, 4 => g4})
        )
      end

      def and_named_capture(capture)
        these_matches(
          self, _capture(self, capture)
        )
      end
    end

    matcher :_capture do|m, capture|
      match do|_|
        [m.match[1], m.match[2], m.match[3], m.match[4]] == capture.values_at(1,2,3,4)
      end
    end
  end

  module Rule
    extend RSpec::Matchers::DSL
    matcher :converts do|value, result|
      match do|rule|
        @matched = rule.apply(value, nil)
        @matched == result
      end
      failure_message_for_should do|rule|
        "match #{value.inspect} to #{rule.inspect}: expected #{result} but #{@matched.inspect}"
      end
    end
  end

end

describe "Usage:" do
  it 'with case expression' do
    p = Patm
    case [1, 2, 3]
    when m = p.match([1, p._1, p._2])
      [m._1, m._2]
    else
      []
    end
      .should == [2, 3]
  end

  it 'with predefined Rule' do
    p = Patm
    r = p::Rule.new do|r|
      r.on [1, p._1, p._2] do|m|
        [m._1, m._2]
      end
      r.else {|obj| [] }
    end
    r.apply([1, 2, 3]).should == [2, 3]
  end

  it 'with predefined Rule(compiled)' do
    p = Patm
    r = p::Rule.new do|r|
      r.on [1, p._1, p._2] do|m|
        [m._1, m._2]
      end
      r.else {|obj| [] }
    end
    r.compile.apply([1, 2, 3]).should == [2, 3]
  end

  it 'with DSL' do
    o = Object.new
    class <<o
      extend ::Patm::DSL
      define_matcher :match1 do|r|
        r.on [1, 2, ::Patm._1] do|m|
          m._1
        end
        r.else do|obj|
          obj.to_s
        end
      end

      define_matcher :match2 do|r|
        r.on [1] do
          1
        end
        r.on [1, ::Patm._xs & ::Patm._1] do|m, _self|
          _self.match1(m._1)
        end
      end
    end

    o.match1([1, 2, 3]).should == 3
    o.match1([1, 2, 4]).should == 4
    o.match1([1, 2]).should == "[1, 2]"

    o.match2([1]).should == 1
    o.match2([1, 2, 3]).should == "[2, 3]"
  end
end

describe Patm::Rule do
  include PatmHelper::Rule
  def self.rule(name, definition, &block)
    [[false, "#{name}"], [true, "#{name}(compiled)"]].each do|compile, name|
      describe name do
        subject { Patm::Rule.new(&definition).tap{|r| break r.compile if compile } }
        self.instance_eval(&block)
      end
    end
  end

  rule(:rule1, ->(r){
    r.on([1, Patm._1, Patm._2]) {|m| [m._1, m._2] }
    r.else { [] }
  }) do
    it { should converts([1, 2, 3], [2, 3]) }
    it { should converts([1], []) }
  end

  rule(:rule2, ->(r) {
    r.on(1) { 100 }
  }) do
    it { should converts(1, 100) }
    it { expect { subject.apply(nil) }.to raise_error(Patm::NoMatchError) }
  end

  context 'regression' do
    rule(:reg1, ->(r){
      _1, _2 = Patm._1, Patm._2
      r.on([1, _1, 2]) {|m| m._1 }
      r.on([1, _1, _2]) {|m| [m._1, m._2] }
      r.on(nil) { 100 }
      r.else { nil }
    }) do
      it { should converts([1, 2, 2], 2) }
      it { should converts([1, 2, 3], [2, 3]) }
      it { should converts(nil, 100) }
      it { should converts([], nil) }
    end

    rule(:reg2, ->(r) { r.else { nil }}) do
      it { should converts(1, nil) }
      it { should converts("hoge", nil) }
    end
  end
end

describe Patm::Pattern do
  include PatmHelper::Pattern
  def self.pattern(plain, &b)
    context "pattern '#{plain.inspect}'" do
      subject { Patm::Pattern.build_from(plain) }
      instance_eval(&b)
    end
    context "pattern '#{plain.inspect}'(Compiled)" do
      subject { Patm::Pattern.build_from(plain).compile }
      instance_eval(&b)
    end
  end

  pattern 1 do
    it { should match_to(1) }
    it { should_not match_to(2) }
  end

  pattern [] do
    it { should match_to [] }
    it { should_not match_to {} }
    it { should_not match_to [1] }
  end

  pattern [1,2] do
    it { should match_to [1,2] }
    it { should_not match_to [1] }
    it { should_not match_to [1, -1] }
    it { should_not match_to [1,2,3] }
  end

  pattern Patm._any do
    it { should match_to 1 }
    it { should match_to ["foo", "bar"] }
  end

  pattern [1, Patm._any, 3] do
    it { should match_to [1, 2, 3] }
    it { should match_to [1, 0, 3] }
    it { should_not match_to [1, 0, 4] }
  end

  pattern Patm.or(1, 2) do
    it { should match_to 1 }
    it { should match_to 2 }
    it { should_not match_to 3 }
  end

  pattern Patm._1 do
    it { should match_to(1).and_capture(1) }
    it { should match_to('x').and_capture('x') }
  end

  pattern Patm._1 & Patm._2 do
    it { should match_to(1).and_capture(1, 1) }
  end

  pattern [0, Patm._1, Patm._2] do
    it { should match_to([0, 1, 2]).and_capture(1, 2) }
    it { should_not match_to(['x', 1, 2]).and_capture(1, 2) }
  end

  pattern [0, 1, Patm._xs] do
    it { should_not match_to([0]) }
    it { should match_to([0, 1]) }
    it { should match_to([0, 1, 2, 3]) }
  end

  pattern [0, 1, Patm._xs & Patm._1] do
    it { should match_to([0, 1]).and_capture([]) }
    it { should match_to([0, 1, 2, 3]).and_capture([2, 3]) }
  end

  pattern [0, 1, Patm._xs[1], 2] do
    it { should match_to([0,1,2]).and_capture([]) }
    it { should match_to([0,1,10,20,30,2]).and_capture([10,20,30]) }
    it { should_not match_to([0,1]) }
  end

  pattern [0, [1, 2]] do
    it { should match_to [0, [1, 2]] }
    it { should_not match_to [0, [1, 3]] }
  end

  pattern Patm._any[:x] do
    it { should match_to("aaa").and_named_capture(:x => "aaa") }
  end

  pattern(a: Patm._any[1]) do
    it { should_not match_to {} }
    it { should match_to(a: 1).and_capture(1) }
    it { should match_to(a: 1, b: 2).and_capture(1) }
  end

  pattern(a: Patm._any, Patm.exact => false) do
    it { should_not match_to(b: 1) }
    it { should     match_to(a: 1) }
    it { should     match_to(a: 1, b: 2) }
  end

  pattern(a: Patm._any, Patm.exact => true) do
    it { should_not match_to(b: 1) }
    it { should     match_to(a: 1) }
    it { should_not match_to(a: 1, b: 2) }
  end

  pattern(a: Patm._any[1].opt) do
    it { should match_to({}).and_capture(nil) }
    it { should match_to({a: 1}).and_capture(1) }
  end

  pattern(a: Patm._any[1], b: Patm._any[2].opt) do
    it { should_not match_to({}) }
    it { should     match_to({a: 1}).and_capture(1, nil) }
    it { should     match_to({a: 1, b: 2}).and_capture(1, 2) }
  end

  pattern({a: 1} => {b: 2}) do
    it { should_not match_to({a: 1} => {b: 0}) }
    it { should_not match_to({a: 0} => {b: 2}) }
    it { should     match_to({a: 1} => {b: 2}) }
  end

  Struct1 = Struct.new(:a, :b)

  pattern(Patm[Struct1].(1, Patm._1)) do
    it { should_not match_to(nil) }
    it { should_not match_to(Struct1.new(2, 2)) }
    it { should     match_to(Struct1.new(1, 2)).and_capture(2) }
  end

  pattern(Patm[Struct1].(a: 1, b: Patm._1)) do
    it { should_not match_to(nil) }
    it { should_not match_to(Struct1.new(2, 2)) }
    it { should     match_to(Struct1.new(1, 2)).and_capture(2) }
  end

  unnamed_struct = Struct.new(:x, :y)
  pattern(Patm[unnamed_struct].(x: 1, y: Patm._1)) do
    it { should_not match_to(nil) }
    it { should match_to(unnamed_struct.new(1, 2)).and_capture(2) }
  end

  context 'regression' do
    pattern [:assign, [:var_field, [:@ident, Patm._1, [Patm._2, Patm._3]]], Patm._4] do
      it { should match_to([:assign, [:var_field, [:@ident, 10, [20, 30]]], false]).and_capture(10, 20, 30, false) }
    end
    pattern [Patm.or(1, 2)] do
      it { should match_to [1] }
      it { should match_to [2] }
    end
    pattern [Patm._1, 2, [Patm._any, 3], Patm._xs[1], 4] do
      it { should match_to([1, 2, [10, 3], 4]).and_capture([]) }
      it { should match_to([1, 2, [10, 3], 20, 4]).and_capture([20]) }
    end
    pattern Patm._1&Array do
      it { should_not match_to(1) }
      it { should     match_to([]).and_capture([]) }
    end
    pattern Patm.or(1, Patm._any) do
      it { should match_to(1) }
      it { should match_to(999) }
    end
  end
end

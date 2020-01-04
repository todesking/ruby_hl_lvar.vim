require File.join(File.dirname(__FILE__), '..', 'lib', 'patm.rb')
require 'benchmark'

P = Patm

def match_with_case(obj)
  _1 = P._1
  _2 = P._2
  _3 = P._3
  _4 = P._4
  _xs = P._xs

  case obj
  when m = P.match([:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4])
    :as
  when m = P.match([:massign, _1, _2])
    :mas
  when m = P.match([:var_ref, [:@ident, _1, [_2, _3]]])
    :vr
  when m = P.match([:params, _1, _2, _3, _xs])
    :par
  when m = P.match(P.or(nil, true, false, Numeric, String, Symbol, []))
    :ignore
  else
    :else
  end
end

@ruledef = lambda do|r|
  _1 = P._1
  _2 = P._2
  _3 = P._3
  _4 = P._4
  _xs = P._xs

  r.on [:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4] do|m|
    :as
  end
  r.on [:massign, _1, _2] do|m|
    :mas
  end
  r.on [:var_ref, [:@ident, _1, [_2, _3]]] do|m|
    :vr
  end
  r.on [:params, _1, _2, _3, _xs] do|m|
    :par
  end
  r.on P.or(nil, true, false, Numeric, String, Symbol, []) do|m|
    :ignore
  end
  r.else do|obj|
    :else
  end
end

@rule = P::Rule.new(&@ruledef)
@compiled_rule = P::Rule.new(&@ruledef).compile

def match_with_rule(obj)
  @rule.apply(obj)
end

def match_with_compiled_rule(obj)
  @compiled_rule.apply(obj)
end


VALUES = [
  [ [:assign, [:var_field, [:@ident, 10, [20, 30]]], false], :as ],
  [ [:massign, 1, 2], :mas],
  [ [:var_ref, [:@ident, "x", [1, 2]]], :vr ],
  [ [:params, 10, 20, 30, 40, 50, 60, 70, 80], :par ],
  [ nil, :ignore ],
  [ 100, :ignore ],
  [ [1,2,3], :else],
]


def bm(&b)
  10000.times do
    VALUES.each do|obj, expected|
      actual = b.call obj
      raise "e:#{expected.inspect} a:#{actual.inspect}" unless actual == expected
    end
  end
end

Benchmark.bm(15) do|b|
  b.report("case-when") { bm {|obj| match_with_case(obj) } }
  b.report("rule") { bm {|obj| match_with_rule(obj) } }
  b.report("compiled-rule") { bm {|obj| match_with_compiled_rule(obj) } }
end


# [:assign, [:var_field, [:@ident, _1, [_2, _3]]], _4] do|m|
# [:massign, _1, _2] do|m|
# [:var_ref, [:@ident, _1, [_2, _3]]] do|m|
# [:params, _1, _2, _3, _xs] do|m|
# p.or(nil, true, false, Numeric, String, Symbol, []) do|m|

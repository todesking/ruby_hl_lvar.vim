require 'benchmark'

def benchmark(klass, n)
  puts "Benchmark: #{klass}(x#{n})"

  target_methods = klass.instance_methods - Object.instance_methods - [:test_values]
  validate(klass, target_methods)

  Benchmark.bm('pattern-match'.size) do|b|
    obj = klass.new
    test_values = obj.test_values
    target_methods.each do|method_name|
      b.report(method_name) do
        m = obj.method(method_name)
        n.times { test_values.each {|val| m.call(val) } }
      end
    end
  end
  puts
end

def validate(klass, target_methods)
  obj = klass.new
  obj.test_values.each do|val|
    results = target_methods.map {|name| [name, obj.public_send(name, val)] }
    unless results.each_cons(2).all?{|(_, a), (_, b)| a == b }
      raise "ERROR: Result not match. val=#{val.inspect}, #{results.map{|n,r| "#{n}=#{r.inspect}"}.join(', ')}"
    end
  end
end

load File.join(File.dirname(__FILE__), '../lib/patm.rb')
require 'pattern-match'

class Empty
  extend Patm::DSL

  def manual(obj)
    nil
  end

  define_matcher :patm do|r|
    r.else { nil }
  end

  def pattern_match(obj)
    match(obj) do
      with(_) { nil }
    end
  end

  def test_values
    [1, 2, 3]
  end
end

class SimpleConst
  extend Patm::DSL

  def manual(obj)
    if obj == 1
      100
    elsif obj == 2
      200
    else
      300
    end
  end

  define_matcher :patm do|r|
    r.on(1) { 100 }
    r.on(2) { 200 }
    r.else { 300 }
  end

  def patm_case(obj)
    case obj
    when m = Patm.match(1)
        100
    when m = Patm.match(2)
        200
    else
      300
    end
  end

  def pattern_match(obj)
    match(obj) do
      with(1) { 100 }
      with(2) { 200 }
      with(_) { 300 }
    end
  end

  def test_values
    [1, 2, 3]
  end
end

class ArrayDecomposition
  extend Patm::DSL

  def manual(obj)
    return 100 unless obj
    return nil unless obj.is_a?(Array)
    return nil if obj.size != 3
    return nil unless obj[0] == 1

    if  obj[2] == 2
      obj[1]
    else
      [obj[1], obj[2]]
    end
  end

  define_matcher :patm do|r|
    _1, _2 = Patm._1, Patm._2
    r.on([1, _1, 2]) {|m| m._1 }
    r.on([1, _1, _2]) {|m| [m._1, m._2] }
    r.on(nil) { 100 }
    r.else { nil }
  end

  def patm_case(obj)
    _1, _2 = Patm._1, Patm._2
    case obj
    when m = Patm.match([1, _1, 2])
      m._1
    when m = Patm.match([1, _1, _2])
      [m._1, m._2]
    when m = Patm.match(nil)
      100
    else
      nil
    end
  end

  def pattern_match(obj)
    match(obj) do
      with(_[1, _1, 2]) { _1 }
      with(_[1, _1, _2]) { [_1, _2] }
      with(nil) { 100 }
      with(_) { nil }
    end
  end

  def test_values
    [
      [],
      [1, 9, 2],
      [1, 9, 3],
      [1, 9, 1],
      [1],
      "foo",
      nil
    ]
  end
end

class VarArray
  extend Patm::DSL

  def manual(obj)
    return nil unless obj.is_a?(Array) && obj.size >= 2 && obj[0] == 1 && obj[1] == 2
    return obj[2..-1]
  end

  define_matcher :patm do|r|
    r.on([1, 2, Patm._xs[1]]) {|m| m[1] }
    r.else { nil }
  end

  def patm_case(obj)
    case obj
    when m = Patm.match([1, 2, Patm._xs[1]])
      m._1
    else
      nil
    end
  end

  def pattern_match(obj)
    match(obj) do
      with(_[1, 2, *_1]) { _1 }
      with(_) { nil }
    end
  end

  def test_values
    [
      nil,
      100,
      [],
      [1, 2],
      [1, 2, 3],
      [1, 2, 3, 4],
      [1, 10, 100],
    ]
  end
end


puts "RUBY_VERSION: #{RUBY_VERSION} p#{RUBY_PATCHLEVEL}"
puts

benchmark Empty, 10000
benchmark SimpleConst, 10000
benchmark ArrayDecomposition, 10000
benchmark VarArray, 10000

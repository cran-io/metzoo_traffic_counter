require 'thread'

class VehicleDetector

  def initialize(file1_n, file2_n, &block)
    @sensor_a = []
    @sensor_b = []
    thread_1 = Thread.new {
      loop do
        if vehicle_detected(file1_n)
          @sensor_a << Time.now.to_f
        end
      end
    }
    thread_2 = Thread.new {
      loop do
        if vehicle_detected(file2_n)
          @sensor_b << Time.now.to_f
        end
      end
    }
    [thread_1, thread_2].each(&:join)
  end

  def vehicle_detected(file_n)
    f = File.open("/sys/class/gpio/gpio#{file_n}/value", "r")
    data = f.read
    f.close
    !data.to_i.zero?
  end

  def vehicle_type
    @sensor_a.zip(@sensor_b).each_slice(2) do |values|
      pair_a = values[0]
      pair_b = values[1]
      dt_a = pair_a.last - pair_a.first
      dt_b = pair_b.last - pair_b.first
      if dt_a.similar_to? dt_b
        return dt_a * SENSONRS_DIST / (pair_b.first - pair_a.first)
      end
    end
  end
end
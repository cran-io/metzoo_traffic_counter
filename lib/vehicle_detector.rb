require 'thread'

class VehicleDetector

  def initialize(file1_n, file2_n, &block)
    sensor_a = sensor_b = []
    @SENSONRS_DIST = 1
    delta_time = Time.now

    sem = Mutex.new
    thread_1 = Thread.new {
      loop do
        sem.synchronize do
          if vehicle_detected(file1_n)
            sensor_a << Time.now
          end
        end
      end
    }
    thread_2 = Thread.new {
      loop do
        sem.synchronize do
          if vehicle_detected(file2_n)
            sensor_b << Time.now
          end

          if sensor_b.count > 1
            if vehicle_type(sensor_a, sensor_b) || Time.now - delta_time > 5
              sensor_a = sensor_b = []
              delta_time = Time.now
            end
          end
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

  def vehicle_type(sensor_a, sensor_b)
    dt_a = sensor_b.first - sensor_a.first
    dt_b = sensor_a.last - sensor_b.last
    if (dt_a - dt_b).abs < 0.5
      length = (sensor_a.last - sensor_a.first) * @SENSONRS_DIST / dt_a
      speed = @SENSONRS_DIST / dt_a
      yield speed, length
      return true
    end
    false
  end
end
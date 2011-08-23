module Nil
  def self.getDeviceBytes(device)
    data = `/sbin/ifconfig #{device}`
    pattern = /RX.+?bytes.+?(\d+).+?TX.+?bytes.+?(\d+)/m
    match = pattern.match(data)
    return nil if match == nil
    return [match[1].to_i, match[2].to_i]
  end

  def self.getDeviceSpeed(device)
    delay = 1.0
    data1 = self.getDeviceBytes(device)
    return if data1 == nil
    sleep delay
    data2 = self.getDeviceBytes(device)
    return if data2 == nil
    output = []
    (0..1).each do |index|
      output << (data2[index] - data1[index]) / delay
    end
    return output
  end

  def self.getDeviceSpeedStrings(device)
    divisor = 1024.0
    speed = self.getDeviceSpeed(device)
    if speed == nil
      return 'Not available'
    end
    data = speed.map { |value| sprintf('%.2f KiB/s', value / divisor) }
    return data
  end
end

require 'timeout'

begin
  timeout(1) do
    puts 'Sleeping'
    sleep 100
    puts 'End of sleep'
  end
rescue Timeout::Error
  puts 'Timeout occured'
end

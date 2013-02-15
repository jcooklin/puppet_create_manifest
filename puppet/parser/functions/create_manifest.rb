module Puppet::Parser::Functions
   newfunction(:create_manifest) do |args|

      ## cache to keep variable values prevents multiple queries
      ## to hiera for the same variable
      $cache = Hash.new

      def error(message)
         raise Puppet::Error, message
      end

      ## returns array containing all variables found within str
      def get_variables(str)
         retArray = Array.new
         unless str.nil? || str.empty?
            retArray = str.scan(/\${\w+}/).map! { |element| 
               element.gsub(/\$|\{|\}/, '')
            }
         end
         return retArray
      end

      ## interpolates all ${variables} found within hash with
      ## variables defined within hiera data sources
      def interpolate_hiera_variables(hash)
         hash.each do |key, value|
            if (value.is_a?(Hash)) then
               interpolate_hiera_variables(value)
            elsif (value.kind_of?(Array)) then
               value.each { |element|
                  interpolate_hiera_variables(element)
               }
            elsif (value.is_a?(String)) then
               variables = get_variables(value)
               variables.each { |variable| 
                  if $cache.has_key?(variable) then
                     value["${" + variable + "}"] = $cache[variable]
                  else
                     hiera_value = function_hiera([variable])
                     value["${" + variable + "}"] = hiera_value
                     $cache[variable] = hiera_value
                  end
               }
            else
            end
         end
      end

      ## TODO - lereyes1 - handle valid parameters
      key = args[0]

      ## interpolate key determines if ${variables} will be interpolated
      interpolate = function_hiera(['interpolate', false])

      ## unable to figure out how to return nil or undef when calling hiera_hash 
      ## renturning an empty hash if key is not found
      manifest = function_hiera_hash([key, {}] )
      if (interpolate) then
         interpolate_hiera_variables(manifest)
      end
      manifest.each do |manifestType, manifestHash|
         ## process resources first
         if (manifestType.start_with?('resources'))
            manifestHash.each do |resourceType, resourceHash|
               method = Puppet::Parser::Functions.function :create_resources
               send(method, [resourceType, resourceHash])
            end
         end
      end
      manifest.each do |manifestType, manifestHash|
         ## process relationships last
         if (manifestType.start_with?('relationships'))
            manifestHash.each do |resourceType, resourceHash|
               method = Puppet::Parser::Functions.function :create_resources
               send(method, [resourceType, resourceHash])
            end
         end
      end
   end
end

-- Debug/helper function
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

-- Load library
MOD_DIR = ".."
local PPM = dofile(MOD_DIR.."/lib/ppm.lua")

-- Load PPM image
local ppm = PPM.read("../ppm-textures/1.ppm")
PPM.info(ppm)

-- Test writing it back
PPM.write(ppm, "/tmp/result1.ppm")

-- Create an empty iamge
local canvas = PPM.new(16, 18)
PPM.info(canvas)

-- Test drawing over canvas
PPM.draw(canvas, ppm, 1, 1)
PPM.info(canvas)

-- Test saving the image we drawn, and reading it back
PPM.write(canvas, "/tmp/result.ppm")
local decoded = PPM.read("/tmp/result.ppm")
if decoded ~= nil then
    print("Success decoding the generated image")
end

-- Test the pixel_array function and the decoding pulled back all data
local decoded_pixels = PPM.pixel_array(decoded)
local expected_pixels = canvas.width * canvas.height
if #decoded_pixels ~= expected_pixels then
    print("Error: decoded pixel_array has "..#decoded_pixels..", expecting "..expected_pixels)
end

-- Encode png
print("Encoding to PNG:")
PPM.info(decoded)
PPM.write_png(decoded, "/tmp/result.png")
print("Worked")
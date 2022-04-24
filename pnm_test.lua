local pnm = pnm_read("textures/1.ppm")
pnm_info(pnm)
pnm_write(pnm, "/tmp/result1.ppm")

local canvas = pnm_new(16, 18)
pnm_info(canvas)
pnm_draw(pnm, canvas, 1, 1)
pnm_info(canvas)
pnm_write(canvas, "/tmp/result.ppm")

local decoded = pnm_read("/tmp/result.ppm")
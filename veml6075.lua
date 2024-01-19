local veml6075 = {}
local device_address = 0x10

function veml6075.start()
	i2c.start(0)
	if not i2c.address(0, device_address, i2c.TRANSMITTER) then
		return false
	end
	i2c.write(0, {0x00, 0x00})
	i2c.stop(0)
	return true
end

function veml6075.read_reg(reg)
	i2c.start(0)
	if not i2c.address(0, device_address, i2c.TRANSMITTER) then
		return
	end
	i2c.write(0, reg)
	i2c.start(0)
	if not i2c.address(0, device_address, i2c.RECEIVER) then
		return
	end
	local data = i2c.read(0, 2)
	i2c.stop(0)
	return string.byte(data, 2) * 256 + string.byte(data, 1)
end

function veml6075.read()
	local uva = veml6075.read_reg(0x07)
	local uvb = veml6075.read_reg(0x09)
	local cvi = veml6075.read_reg(0x0a)
	local cir = veml6075.read_reg(0x0b)

	if uva == nil or uvb == nil or cvi == nil or cir == nil then
		return
	end

	local uva_c = uva - 2.22 * cvi - 1.33 * cir
	local uvb_c = uvb - 2.95 * cvi - 1.74 * cir
	veml6075.uva = uva_c * 0.93
	veml6075.uvb = uvb_c * 2.1
	veml6075.uva_i = uva_c * 0.001461
	veml6075.uvb_i = uvb_c * 0.002591
	return true
end

return veml6075

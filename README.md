# ESP8266 Lua/NodeMCU module for VEML6075 UV irradiance sensors

This repository contains an ESP8266 NodeMCU Lua module (`sen5x.lua`) as well as
MQTT / HomeAssistant / InfluxDB integration example (`init.lua`) for
**VEML6075** UV irradiance sensors connected via I²C.

## Dependencies

veml6075.lua has been tested with Lua 5.1 on NodeMCU firmware 3.0.1 (Release
202112300746, integer build). It requires the following modules.

* i2c

The MQTT HomeAssistant integration in init.lua additionally needs the following
modules.

* gpio
* mqtt
* node
* tmr
* wifi

## Setup

Connect the VEML6075 sensor to your ESP8266/NodeMCU board as follows.

* VEML6075 GND → ESP8266/NodeMCU GND
* VEML6075 VCC → ESP8266/NodeMCU 3V3
* VEML6075 SDA → NodeMCU D1 (ESP8266 GPIO5)
* VEML6075 SCL → NodeMCU D2 (ESP8266 GPIO4)

If you use different pins for SCL and SDA, you need to adjust the i2c.setup
call in the examples provided in this repository to reflect those changes. Keep
in mind that some ESP8266 pins must have well-defined logic levels at boot time
and may therefore be unsuitable for VEML6075 connection.

## Usage

Copy **veml6075.lua** to your NodeMCU board and set it up as follows.

```lua
veml6075 = require("veml6075")
i2c.setup(0, 1, 2, i2c.SLOW)
veml6075.start()

-- can be called with up to 10 Hz
function some_timer_callback()
	if veml6075.read() then
		-- All values are float
		-- veml6075.uva   : UV-A irradiance [µW/cm²]
		-- veml6075.uvb   : UV-B irradiance [µW/cm²]
		-- veml6075.uva_i : UV-A index
		-- veml6075.uvb_i : UV-B index
	end
end
```

## Application Example

**init.lua** is an example application with HomeAssistant integration.
To use it, you need to create a **config.lua** file with WiFI and MQTT settings:

```lua
station_cfg = {ssid = "...", pwd = "..."}
mqtt_host = "..."
```

Optionally, it can also publish readings to InfluxDB.
To do so, configure URL and attribute:

```lua
influx_url = "..."
influx_attr = "..."
```

Readings will be published as `veml6075[influx_attr] uva_uwcm2=%f,uvb_uwcm2=%f,uv_index=%f`.
So, unless `influx_attr = ''`, it must start with a comma, e.g. `influx_attr = ',device=' .. device_id`.

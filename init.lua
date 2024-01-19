publishing_mqtt = false
publishing_http = false

watchdog = tmr.create()
push_timer = tmr.create()
chip_id = string.format("%06X", node.chipid())
device_id = "esp8266_" .. chip_id
mqtt_prefix = "sensor/" .. device_id
mqttclient = mqtt.Client(device_id, 120)

dofile("config.lua")

print("VEML6075 " .. chip_id)

ledpin = 4
gpio.mode(ledpin, gpio.OUTPUT)
gpio.write(ledpin, 0)

veml6075 = require("veml6075")
i2c.setup(0, 1, 2, i2c.SLOW)

function log_restart()
	print("Network error " .. wifi.sta.status())
end

function setup_client()
	print("Connected")
	gpio.write(ledpin, 1)
	if not veml6075.start() then
		print("VEML6075 initialization error")
	end
	publishing_mqtt = true
	mqttclient:publish(mqtt_prefix .. "/state", "online", 0, 1, function(client)
		publishing_mqtt = false
		push_timer:start()
	end)
end

function connect_mqtt()
	print("IP address: " .. wifi.sta.getip())
	print("Connecting to MQTT " .. mqtt_host)
	mqttclient:on("connect", hass_register)
	mqttclient:on("offline", log_restart)
	mqttclient:lwt(mqtt_prefix .. "/state", "offline", 0, 1)
	mqttclient:connect(mqtt_host)
end

function connect_wifi()
	print("WiFi MAC: " .. wifi.sta.getmac())
	print("Connecting to ESSID " .. station_cfg.ssid)
	wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, connect_mqtt)
	wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, log_restart)
	wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, log_restart)
	wifi.setmode(wifi.STATION)
	wifi.sta.config(station_cfg)
	wifi.sta.connect()
end

function push_data()
	if not veml6075.read() then
		print("VEML6075 error")
		return
	end
	local json_str = string.format('{"uva_uwcm2":%.1f,"uvb_uwcm2":%.1f,"uv_index":%.0f,"rssi_dbm":%d}', veml6075.uva, veml6075.uvb, (veml6075.uva_i + veml6075.uvb_i)/2, wifi.sta.getrssi())
	local influx_str = string.format('uva_uwcm2=%f,uvb_uwcm2=%f,uv_index=%f', veml6075.uva, veml6075.uvb, (veml6075.uva_i + veml6075.uvb_i)/2)
	if not publishing_mqtt then
		publishing_mqtt = true
		watchdog:start(true)
		gpio.write(ledpin, 0)
		mqttclient:publish(mqtt_prefix .. "/data", json_str, 0, 0, function(client)
			publishing_mqtt = false
			if influx_url and influx_attr and influx_str then
				publish_influx(influx_str)
			else
				gpio.write(ledpin, 1)
				collectgarbage()
			end
		end)
	end
end

function publish_influx(payload)
	if not publishing_http then
		publishing_http = true
		http.post(influx_url, influx_header, "veml6075" .. influx_attr .. " " .. payload, function(code, data)
			publishing_http = false
			gpio.write(ledpin, 1)
			collectgarbage()
		end)
	end
end

function hass_register()
	local hass_device = string.format('{"connections":[["mac","%s"]],"identifiers":["%s"],"model":"ESP8266 + VEML6075","name":"VEML6075 %s","manufacturer":"derf"}', wifi.sta.getmac(), device_id, chip_id)
	local hass_entity_base = string.format('"device":%s,"state_topic":"%s/data","expire_after":600', hass_device, mqtt_prefix)
	local hass_uva = string.format('{%s,"name":"UVA","object_id":"%s_uva","unique_id":"%s_uva","device_class":"irradiance","unit_of_measurement":"µW/cm²","value_template":"{{value_json.uva_uwcm2}}"}', hass_entity_base, device_id, device_id)
	local hass_uvb = string.format('{%s,"name":"UVB","object_id":"%s_uvb","unique_id":"%s_uvb","device_class":"irradiance","unit_of_measurement":"µW/cm²","value_template":"{{value_json.uvb_uwcm2}}"}', hass_entity_base, device_id, device_id)
	local hass_uvi = string.format('{%s,"name":"UV Index","object_id":"%s_uvi","unique_id":"%s_uvi","device_class":"irradiance","unit_of_measurement":"counts","value_template":"{{value_json.uv_index}}"}', hass_entity_base, device_id, device_id)
	local hass_rssi = string.format('{%s,"name":"RSSI","object_id":"%s_rssi","unique_id":"%s_rssi","device_class":"signal_strength","unit_of_measurement":"dBm","value_template":"{{value_json.rssi_dbm}}","entity_category":"diagnostic"}', hass_entity_base, device_id, device_id)

	mqttclient:publish("homeassistant/sensor/" .. device_id .. "/uva/config", hass_uva, 0, 1, function(client)
		mqttclient:publish("homeassistant/sensor/" .. device_id .. "/uvb/config", hass_uvb, 0, 1, function(client)
			mqttclient:publish("homeassistant/sensor/" .. device_id .. "/uvi/config", hass_uvi, 0, 1, function(client)
				mqttclient:publish("homeassistant/sensor/" .. device_id .. "/rssi/config", hass_rssi, 0, 1, function(client)
					collectgarbage()
					setup_client()
				end)
			end)
		end)
	end)
end

watchdog:register(180 * 1000, tmr.ALARM_SEMI, node.restart)
push_timer:register(10 * 1000, tmr.ALARM_AUTO, push_data)
watchdog:start()

connect_wifi()

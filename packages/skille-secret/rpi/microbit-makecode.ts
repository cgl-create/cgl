// CGL+ LabZ micro:bit v2 BLE display
// Add the "bluetooth" extension in MakeCode.
// Project Settings: enable "No Pairing Required: Anyone can connect via Bluetooth."

bluetooth.startUartService()
bluetooth.setTransmitPower(7)
basic.showIcon(IconNames.Asleep)

bluetooth.onUartDataReceived("\n", function () {
    let message = bluetooth.uartReadUntil("\n").trim()
    if (message == "NORMAL") basic.showIcon(IconNames.Yes)
    else if (message == "ALERT") basic.showIcon(IconNames.No)
    else if (message.indexOf("WARMUP:") == 0) basic.showNumber(parseInt(message.substr(7)))
})

bluetooth.onBluetoothConnected(function () { basic.showIcon(IconNames.Happy) })
bluetooth.onBluetoothDisconnected(function () { basic.showIcon(IconNames.Sad) })

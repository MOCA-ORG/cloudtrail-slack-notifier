const config = require('config')

exports.filters = {
    consoleLogin: (record) => {
        const event = record.eventName
        const name = record.userIdentity.userName
        const ip = record.sourceIPAddress
        const error = record.errorMessage
        if (event !== 'ConsoleLogin') {
            return null
        } else if (error) {
            return `:warning: [${name}] Console login failed from ${ip}. Error: ${error}`
        } else if (config.TRUSTED_IPS.indexOf(ip) !== -1) {
            return `:large_green_circle: [${name || "ROOT"}] Console login from trusted IP(${ip}) detected.`
        } else {
            return `:red_circle: [${name || "ROOT"}] Console login from untrusted IP(${ip}) detected.`
        }
    }
}

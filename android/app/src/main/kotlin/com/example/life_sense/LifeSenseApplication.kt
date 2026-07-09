package com.example.life_sense

import android.app.Application
import com.huawei.agconnect.AGCRoutePolicy
import com.huawei.agconnect.AGConnectInstance
import com.huawei.agconnect.AGConnectOptionsBuilder

class LifeSenseApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (AGConnectInstance.getInstance() != null) {
            return
        }
        val builder = AGConnectOptionsBuilder()
            .setRoutePolicy(AGCRoutePolicy.CHINA)
            .setCustomValue("agcgw/url", "connect-drcn.dbankcloud.cn")
            .setCustomValue("agcgw/backurl", "connect-drcn.hispace.hicloud.com")
            .setCustomValue("/agcgw/url", "connect-drcn.dbankcloud.cn")
            .setCustomValue("/agcgw/backurl", "connect-drcn.hispace.hicloud.com")
        assets.open("agconnect-services.json").use { inputStream ->
            builder.setInputStream(inputStream)
            AGConnectInstance.initialize(applicationContext, builder)
        }
    }
}

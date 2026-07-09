/*
 * Copyright 2020-2023. Huawei Technologies Co., Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.huawei.agconnectcore;

import android.app.Activity;

import androidx.annotation.NonNull;

import com.huawei.agconnect.AGCRoutePolicy;
import com.huawei.agconnect.AGConnectInstance;
import com.huawei.agconnect.AGConnectOptionsBuilder;
import com.huawei.agconnectcore.handlers.AGConnectCoreMethodHandler;

import java.io.IOException;
import java.io.InputStream;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;

public class AGConnectCorePlugin implements FlutterPlugin, ActivityAware {
    private MethodChannel channel;
    private FlutterPluginBinding flutterPluginBinding;
    private AGConnectCoreMethodHandler agConnectCoreMethodHandler;
    private AGConnectCoreModule agConnectCoreModule;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
        if (flutterPluginBinding != null) {
            initializeAGConnect(activityPluginBinding.getActivity());
            initChannels(flutterPluginBinding.getBinaryMessenger());
            setHandlers(activityPluginBinding.getActivity());
        }
    }

    private void initializeAGConnect(Activity activity) {
        if (AGConnectInstance.getInstance() != null) {
            return;
        }
        AGConnectOptionsBuilder builder = new AGConnectOptionsBuilder()
                .setRoutePolicy(AGCRoutePolicy.CHINA)
                .setCustomValue("agcgw/url", "connect-drcn.dbankcloud.cn")
                .setCustomValue("agcgw/backurl", "connect-drcn.hispace.hicloud.com")
                .setCustomValue("/agcgw/url", "connect-drcn.dbankcloud.cn")
                .setCustomValue("/agcgw/backurl", "connect-drcn.hispace.hicloud.com");
        try {
            InputStream inputStream = activity.getApplicationContext().getAssets().open("agconnect-services.json");
            builder.setInputStream(inputStream);
        } catch (IOException e) {
            Log.w("AGConnectCore", "agconnect-services.json asset not found.");
        }
        AGConnectInstance.initialize(activity.getApplicationContext(), builder);
    }

    private void initChannels(BinaryMessenger binaryMessenger) {
        channel = new MethodChannel(binaryMessenger, "com.huawei.flutter/agconnect_core");
    }

    private void setHandlers(Activity activity) {
        agConnectCoreModule = new AGConnectCoreModule(activity);
        agConnectCoreMethodHandler = new AGConnectCoreMethodHandler(agConnectCoreModule, activity.getApplicationContext());
        channel.setMethodCallHandler(agConnectCoreMethodHandler);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        agConnectCoreModule = null;
        channel = null;
        agConnectCoreMethodHandler = null;
    }
}

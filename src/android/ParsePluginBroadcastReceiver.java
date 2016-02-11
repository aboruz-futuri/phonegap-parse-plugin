package org.apache.cordova.core;

import com.parse.ParsePushBroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class ParsePluginBroadcastReceiver extends ParsePushBroadcastReceiver
{

    @Override
    protected void onPushReceive(Context context, Intent intent) {}

    @Override
    protected void onPushOpen(Context context, Intent intent) {}

}

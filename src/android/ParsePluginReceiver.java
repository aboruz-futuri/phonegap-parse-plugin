package org.apache.cordova.core;

import com.earliz.app.R;
import com.parse.ParsePushBroadcastReceiver;
import com.parse.ParseAnalytics;

import android.app.Activity;
import android.app.Notification;
import android.app.TaskStackBuilder;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.net.Uri;
import android.util.Log;

import org.json.JSONObject;
import org.json.JSONException;

public class ParsePluginReceiver extends ParsePushBroadcastReceiver
{
    private static final String TAG = "ParsePluginReceiver";
    private static final String RECEIVED_IN_FOREGROUND = "receivedInForeground";

    @Override
    protected void onPushReceive(Context context, Intent intent) {
        JSONObject pushData = getPushData(intent);

        if (pushData != null) {
            if (ParsePlugin.isInForeground()) {
                ParsePlugin.javascriptEventCallback(pushData);
            } else {
                super.onPushReceive(context, intent);
            }
        }
    }

    @Override
    protected void onPushOpen(Context context, Intent intent) {
        JSONObject pushData = getPushData(intent);

        if (pushData != null) {
            if (ParsePlugin.isInForeground()) {
                ParseAnalytics.trackAppOpened(intent);
                ParsePlugin.javascriptEventCallback(pushData);
            } else {
                super.onPushOpen(context, intent);
                ParsePlugin.setLaunchNotification(pushData);
            }
        }
    }

    @Override
    protected Notification getNotification(Context context, Intent intent) {
        Notification notification = super.getNotification(context, intent);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            notification.color = context.getResources().getColor(R.color.background_notif_icon);
        }
        return notification;
    }

    private static JSONObject getPushData(Intent intent){
        JSONObject pushData = null;
        try {
            pushData = new JSONObject(intent.getStringExtra("com.parse.Data"));
            pushData.put(RECEIVED_IN_FOREGROUND, ParsePlugin.isInForeground());
        } catch (JSONException e) {
            Log.e(TAG, "JSONException while parsing push data:", e);
        } finally{
            return pushData;
        }
    }
}

package de.selfmade4u.rust;

import android.os.Bundle;
import android.widget.Button;

public class MainActivity extends android.app.Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setContentView(new Button(getApplicationContext()));
    }
}
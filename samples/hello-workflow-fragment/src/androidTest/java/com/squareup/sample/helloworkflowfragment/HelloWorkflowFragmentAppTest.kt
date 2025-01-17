package com.squareup.sample.helloworkflowfragment

import android.os.Build
import androidx.test.espresso.action.ViewActions.click
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withText
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import com.squareup.workflow1.ui.WorkflowUiExperimentalApi
import com.squareup.workflow1.ui.internal.test.inAnyView
import org.hamcrest.Matchers.containsString
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

// Life is too short to debug why LeakCanary breaks this on API 21
// https://github.com/square/workflow-kotlin/issues/582
@SdkSuppress(minSdkVersion = Build.VERSION_CODES.M)
@RunWith(AndroidJUnit4::class)
@OptIn(WorkflowUiExperimentalApi::class)
class HelloWorkflowFragmentAppTest {

  @get:Rule val scenarioRule = ActivityScenarioRule(HelloWorkflowFragmentActivity::class.java)

  @Test fun togglesHelloAndGoodbye() {
    inAnyView(withText(containsString("Hello")))
      .check(matches(isDisplayed()))
      .perform(click())

    inAnyView(withText(containsString("Goodbye")))
      .check(matches(isDisplayed()))
      .perform(click())

    inAnyView(withText(containsString("Hello")))
      .check(matches(isDisplayed()))
  }
}

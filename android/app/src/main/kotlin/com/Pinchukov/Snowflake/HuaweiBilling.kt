package com.Pinchukov.Snowflake

import android.app.Activity
import android.content.Intent
import android.content.IntentSender.SendIntentException
import android.util.Log
import com.huawei.hms.iap.Iap
import com.huawei.hms.iap.IapApiException
import com.huawei.hms.iap.entity.InAppPurchaseData
import com.huawei.hms.iap.entity.OrderStatusCode
import com.huawei.hms.iap.entity.OwnedPurchasesReq
import com.huawei.hms.iap.entity.ProductInfoReq
import com.huawei.hms.iap.entity.PurchaseIntentReq
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Purchases through Huawei IAP, for the AppGallery build (branch huawei).
///
/// The in_app_purchase plugin only speaks Play Billing, and Huawei phones
/// since 2020 ship without Google services, so the shop talks to IAP here
/// over the "snowflake/iap" channel. Adapted from Excellence's HuaweiBilling.
///
/// Snowflakes sells non-consumables only (the sets): bought once, owned for
/// good, never consumed. "Restore" is simply the list of owned ones.
class HuaweiBilling(private val activity: Activity) : MethodChannel.MethodCallHandler {

    /// The reply to a purchase under way: the payment sheet answers in
    /// onActivityResult, not in the Task.
    private var pendingPurchase: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> isReady(result)
            "prices" -> loadPrices(call.argument<List<String>>("ids").orEmpty(), result)
            "buy" -> buy(call.argument<String>("id").orEmpty(), result)
            "owned" -> owned(result)
            else -> result.notImplemented()
        }
    }

    /// Whether the store can be used: HMS Core present, signed in to a
    /// HUAWEI ID, and the account's country supports payments. Sign-in is
    /// not raised here; the shop just says purchases are unavailable.
    private fun isReady(result: MethodChannel.Result) {
        Iap.getIapClient(activity).isEnvReady
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { e ->
                Log.w(TAG, "store not ready, code=" + codeOf(e))
                result.success(false)
            }
    }

    /// The products' prices, in the player's currency, by id.
    private fun loadPrices(ids: List<String>, result: MethodChannel.Result) {
        val request = ProductInfoReq().apply {
            priceType = NON_CONSUMABLE
            productIds = ids
        }
        Iap.getIapClient(activity).obtainProductInfo(request)
            .addOnSuccessListener { response ->
                val prices = HashMap<String, String>()
                for (product in response.productInfoList.orEmpty()) {
                    prices[product.productId] = product.price
                }
                // Fewer than asked: a product not set up or not active in
                // AppGallery Connect. Silently that looks like "the shop is broken".
                if (prices.size < ids.size) Log.w(TAG, "store knows " + prices.size + " of " + ids.size + " products")
                result.success(prices)
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "no prices, code=" + codeOf(e))
                result.success(HashMap<String, String>())
            }
    }

    /// Opens the payment sheet. Answers {ok, id} or {ok: false, reason}.
    private fun buy(id: String, result: MethodChannel.Result) {
        if (pendingPurchase != null) {
            result.success(failure("busy"))
            return
        }
        val request = PurchaseIntentReq().apply {
            productId = id
            priceType = NON_CONSUMABLE
        }
        pendingPurchase = result
        Iap.getIapClient(activity).createPurchaseIntent(request)
            .addOnSuccessListener { response ->
                val status = response.status
                if (!status.hasResolution()) {
                    answer(failure("no_resolution"))
                    return@addOnSuccessListener
                }
                try {
                    status.startResolutionForResult(activity, REQUEST_BUY)
                } catch (e: SendIntentException) {
                    answer(failure("intent_failed"))
                }
            }
            .addOnFailureListener { e -> answer(failure(reasonOf(e))) }
    }

    fun onActivityResult(requestCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_BUY) return false
        if (data == null) {
            answer(failure("cancelled"))
            return true
        }
        val info = Iap.getIapClient(activity).parsePurchaseResultInfoFromIntent(data)
        when (info.returnCode) {
            OrderStatusCode.ORDER_STATE_SUCCESS -> answer(hashMapOf("ok" to true, "id" to productOf(info.inAppPurchaseData)))
            OrderStatusCode.ORDER_STATE_CANCEL -> answer(failure("cancelled"))
            // Paid with a method that settles later: the set comes with the
            // next "owned" check, once the payment goes through.
            OrderStatusCode.ORDER_STATE_PENDING -> answer(failure("pending"))
            // Already bought (another device, an interrupted try): owned
            // picks it up.
            OrderStatusCode.ORDER_PRODUCT_OWNED -> answer(failure("owned"))
            else -> answer(failure("failed_${info.returnCode}"))
        }
        return true
    }

    /// The ids of everything bought before, on this account.
    private fun owned(result: MethodChannel.Result) {
        val request = OwnedPurchasesReq().apply { priceType = NON_CONSUMABLE }
        Iap.getIapClient(activity).obtainOwnedPurchases(request)
            .addOnSuccessListener { response ->
                val ids = ArrayList<String>()
                for (data in response.inAppPurchaseDataList.orEmpty()) {
                    val purchase = try {
                        InAppPurchaseData(data)
                    } catch (e: Exception) {
                        continue
                    }
                    // Only paid ones; a refunded or cancelled one is not owned.
                    if (purchase.purchaseState == InAppPurchaseData.PurchaseState.PURCHASED) {
                        ids.add(purchase.productId)
                    }
                }
                result.success(ids)
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "owned failed, code=" + codeOf(e))
                result.success(ArrayList<String>())
            }
    }

    private fun productOf(data: String?): String? = try {
        InAppPurchaseData(data).productId
    } catch (e: Exception) {
        null
    }

    private fun codeOf(e: Exception): Int? = (e as? IapApiException)?.statusCode

    /// Answers the purchase under way exactly once.
    private fun answer(value: HashMap<String, Any?>) {
        val result = pendingPurchase ?: return
        pendingPurchase = null
        result.success(value)
    }

    private fun failure(reason: String): HashMap<String, Any?> = hashMapOf("ok" to false, "reason" to reason)

    private fun reasonOf(e: Exception): String {
        if (e !is IapApiException) return "error"
        return when (e.statusCode) {
            OrderStatusCode.ORDER_HWID_NOT_LOGIN -> "not_logged_in"
            OrderStatusCode.ORDER_ACCOUNT_AREA_NOT_SUPPORTED -> "area_not_supported"
            OrderStatusCode.ORDER_PRODUCT_OWNED -> "owned"
            else -> "error_${e.statusCode}"
        }
    }

    private companion object {
        const val TAG = "SnowflakeIap"
        const val NON_CONSUMABLE = 1
        const val REQUEST_BUY = 8804
    }
}

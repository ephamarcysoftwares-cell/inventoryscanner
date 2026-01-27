 <?php
// Directly use the path found in the registry
$jsonFilePath = "C:\\Users\\Public\\payzz\\payment_974801fa-4211-4f44-be39-dbfe5680f6c6.json";

// Check if the file exists
if (file_exists($jsonFilePath)) {
    // Get the content of the file
    $jsonData = file_get_contents($jsonFilePath);

    // Decode the JSON data into an associative array
    $paymentData = json_decode($jsonData, true);

    // Check if JSON is valid
    if (json_last_error() !== JSON_ERROR_NONE) {
        echo "<p>Error decoding JSON: " . json_last_error_msg() . "</p>";
        exit();
    }

    // Check if JSON is an array and get the first element
    if (isset($paymentData[0])) {
        $paymentData = $paymentData[0];  // Take first element if it's an array
    }

    // Validate required keys
    $status = isset($paymentData['status']) ? htmlspecialchars($paymentData['status']) : "N/A";
    $message = isset($paymentData['message']) ? htmlspecialchars($paymentData['message']) : "N/A";
    $payment_method = isset($paymentData['payment_method']) ? htmlspecialchars($paymentData['payment_method']) : "N/A";
    $amount = isset($paymentData['amount']) ? htmlspecialchars($paymentData['amount']) . " USD" : "N/A";
    $confirmation_code = isset($paymentData['confirmation_code']) ? htmlspecialchars($paymentData['confirmation_code']) : "N/A";
    $order_tracking_id = isset($paymentData['order_tracking_id']) ? htmlspecialchars($paymentData['order_tracking_id']) : "N/A";
    $merchant_reference = isset($paymentData['merchant_reference']) ? htmlspecialchars($paymentData['merchant_reference']) : "N/A";
    
    // Get the next payment date (30 days from the current date)
    $paymentDate = date('Y-m-d H:i:s'); // Current date and time
    $nextPaymentDate = date('Y-m-d H:i:s', strtotime($paymentDate . ' + 30 days')); // Add 30 days

    // Display transaction details
    echo "<h2>Transaction Details</h2>";
    echo "<div class='details'>";
    echo "<p><strong>Status:</strong> $status</p>";
    echo "<p><strong>Message:</strong> $message</p>";
    echo "<p><strong>Payment Method:</strong> $payment_method</p>";
    echo "<p><strong>Amount:</strong> $amount</p>";
    echo "<p><strong>Confirmation Code:</strong> $confirmation_code</p>";
    echo "<p><strong>Order Tracking ID:</strong> $order_tracking_id</p>";
    echo "<p><strong>Merchant Reference:</strong> $merchant_reference</p>";
    echo "<p><strong>Payment Date:</strong> $paymentDate</p>";
    echo "<p><strong>Next Payment Date:</strong> $nextPaymentDate</p>";  // Add the next payment date
    echo "</div>";
} else {
    echo "<p>Payment file does not exist at the specified path.</p>";
}
?>

<!-- HTML link to go back to the home page with forced browser close -->
 <a href="index.php" onclick="confirmClose(); return false;" class="btn">Back to Home</a>

<script type="text/javascript">
    function confirmClose() {
        // Custom message to ask the user to manually close the window
        if (confirm('Thank you for trusting E-PHARMACY SOFTWARE? Please manually close this tab now.')) {
            // You can suggest the user to close the window, but closing will not work in modern browsers.
            alert("Please close the tab manually.");
        }
    }
</script>

<style>
    body {
        font-family: Arial, sans-serif;
        background-color: #f4f7fc;
        color: #333;
        margin: 0;
        padding: 0;
    }

    h2 {
        text-align: center;
        margin-top: 50px;
        color: #2c3e50;
    }

    .details {
        width: 80%;
        max-width: 800px;
        margin: 20px auto;
        background-color: #fff;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }

    .details p {
        font-size: 16px;
        line-height: 1.6;
        color: #7f8c8d;
    }

    .details strong {
        color: #2c3e50;
    }

    .btn {
        display: inline-block;
        background-color: #2980b9;
        color: white;
        padding: 10px 20px;
        text-decoration: none;
        border-radius: 5px;
        text-align: center;
        margin: 20px auto;
        font-size: 16px;
    }

    .btn:hover {
        background-color: #3498db;
    }
</style>

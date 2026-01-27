 <?php
include 'acesstoken.php'; // Token is used only internally, never displayed

// Set the time zone to East Africa Time (UTC+3)
date_default_timezone_set('Africa/Nairobi');

// Write the file path to the Windows Registry
function writeRegistry($filePath) {
    // Define the registry key and value
    $regKey = "HKEY_LOCAL_MACHINE\\SOFTWARE\\EPharmacyConfig";
    $regValueName = "PaymentFilePath";

    // Command to add the registry key with the file path
    $command = "reg add \"$regKey\" /v \"$regValueName\" /t REG_SZ /d \"$filePath\" /f";

    // Execute the command
    exec($command, $output, $result);

    if ($result == 0) {
        // echo "Registry key added successfully!<br>";
    } else {
        // echo "Failed to add registry key.<br>";
    }
}

// Read the file path from the Windows Registry
function readRegistry() {
    // Define the registry key and value
    $regKey = "HKEY_LOCAL_MACHINE\\SOFTWARE\\EPharmacyConfig";
    $regValueName = "PaymentFilePath";

    // Command to query the registry value
    $command = "reg query \"$regKey\" /v \"$regValueName\"";
    exec($command, $output, $result);

    if ($result == 0) {
        // Parse the output to get the value
        $path = '';
        foreach ($output as $line) {
            if (strpos($line, 'REG_SZ') !== false) {
                // Extract the file path from the registry output
                $path = trim(substr($line, strpos($line, 'REG_SZ') + 7));
            }
        }

        // echo "The saved path is: " . $path . "<br>";
    } else {
        // echo "Failed to read the registry key.<br>";
    }
}

// Get parameters from the URL
$OrderTrackingId = isset($_GET['OrderTrackingId']) ? $_GET['OrderTrackingId'] : null;
$OrderMerchantReference = isset($_GET['OrderMerchantReference']) ? $_GET['OrderMerchantReference'] : null;

// Validate parameters
if (!$OrderTrackingId || !$OrderMerchantReference) {
    // echo json_encode(array("error" => "Missing required parameters: OrderTrackingId or OrderMerchantReference"));
    exit;
}

// Set the API URL based on the environment
$apiBaseUrl = (defined('APP_ENVIROMENT') && APP_ENVIROMENT == 'sandbox') 
    ? "https://cybqa.pesapal.com/pesapalv3/api/Transactions/GetTransactionStatus"
    : "https://pay.pesapal.com/v3/api/Transactions/GetTransactionStatus";

$getTransactionStatusUrl = "$apiBaseUrl?orderTrackingId=$OrderTrackingId";

// Set headers (Token is **not** printed)
$headers = [
    "Accept: application/json",
    "Content-Type: application/json",
    "Authorization: Bearer $token"
];

// Make API request
$ch = curl_init($getTransactionStatusUrl);
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$responseCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

// Check for cURL errors
if (curl_errno($ch)) {
    echo json_encode(["error" => "cURL error: " . curl_error($ch)]);
    exit;
}

// Process API response
if ($responseCode == 200) {
    $data = json_decode($response, true);

    // Check if response contains the required fields
    if (isset($data['payment_status_description'])) {
        $status = strtolower($data['payment_status_description']);

        // Prepare response data (without exposing the token)
        $paymentDate = date('Y-m-d H:i:s'); // Current date and time in UTC+3
        $nextPaymentDate = date('Y-m-d H:i:s', strtotime($paymentDate . ' + 30 days')); // Add 30 days

        $transactionResponse = [
            "status" => ucfirst($status),
            "message" => ($status == "completed") ? "Transaction completed successfully. Thank you for trusting E-pharmacy!" :
                (($status == "cancelled") ? "Transaction was cancelled by the user." : "Transaction is still pending or failed."),
            "payment_method" => $data['payment_method'],
            "amount" => $data['amount'], // Amount remains as is, but will be displayed as TSH
            "confirmation_code" => $data['confirmation_code'],
            "order_tracking_id" => $data['order_tracking_id'],
            "merchant_reference" => $data['merchant_reference'],
            "currency" => $data['currency'],
            "payment_date" => date('Y-m-d H:i:s'),
            "next_payment_date" => date('Y-m-d H:i:s', strtotime('+1 month'))
        ];

        // Define the folder path to save the data
        $folderPath = "C:\\Users\\Public\\payzz"; 

        // Ensure the 'payzz' directory exists and is writable
        if (!file_exists($folderPath)) {
            if (mkdir($folderPath, 0777, true)) {
                // echo "Folder created successfully at: $folderPath <br>";
            } else {
                // echo "Failed to create folder at: $folderPath <br>";
            }
        } else {
            // echo "Folder already exists at: $folderPath <br>";
        }

        // Define file path for saving the transaction data (using fixed filename)
        $filePath = $folderPath . "\\payment_974801fa-4211-4f44-be39-dbfe5680f6c6.json";

        // Check if the file exists
        if (!file_exists($filePath)) {
            // File does not exist, create it and write the initial data
            $initialData = [$transactionResponse]; // Initial transaction data array

            // Create the file and save the transaction data
            if (file_put_contents($filePath, json_encode($initialData, JSON_PRETTY_PRINT))) {
                // echo "File created successfully at: $filePath <br>";
            } else {
                // echo "Failed to write to the file: $filePath <br>";
            }
        } else {
            // File exists, update its contents
            $existingData = json_decode(file_get_contents($filePath), true); // Get existing data
            
            // Update the contents with new transaction data (replace existing content)
            $updatedData = [$transactionResponse]; // Replace with a single transaction response

            // Save updated data to the file, overwriting the existing file contents
            if (file_put_contents($filePath, json_encode($updatedData, JSON_PRETTY_PRINT))) {
                // echo "File updated successfully at: $filePath <br>";
            } else {
                // echo "Failed to write to the file: $filePath <br>";
            }
        }

        // Write the file path to the registry
        writeRegistry($filePath);

        // Display transaction details with TSH in the amount section
        echo '<!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Transaction Status</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
            <style>
                body {
                    background-color: #f8f9fa;
                    font-family: Arial, sans-serif;
                }
                .container {
                    max-width: 600px;
                    margin: 50px auto;
                    background: white;
                    padding: 20px;
                    border-radius: 8px;
                    box-shadow: 0px 0px 10px rgba(0, 0, 0, 0.1);
                }
                .table th {
                    background-color: #007bff;
                    color: white;
                }
                .status-completed {
                    color: green;
                    font-weight: bold;
                }
                .status-cancelled {
                    color: red;
                    font-weight: bold;
                }
                .status-pending {
                    color: orange;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h3 class="text-center">Transaction Details</h3>
                <table class="table table-bordered">
                    <tr>
                        <th>Status</th>
                        <td class="status-' . strtolower($transactionResponse["status"]) . '">' . ucfirst($transactionResponse["status"]) . '</td>
                    </tr>
                    <tr>
                        <th>Message</th>
                        <td>' . $transactionResponse["message"] . '</td>
                    </tr>
                    <tr>
                        <th>Payment Method</th>
                        <td>' . $transactionResponse["payment_method"] . '</td>
                    </tr>
                    <tr>
                        <th>Amount</th>
                        <td>' . $transactionResponse["amount"] . ' TSH</td>
                    </tr>
                    <tr>
                        <th>Confirmation Code</th>
                        <td>' . $transactionResponse["confirmation_code"] . '</td>
                    </tr>
                    <tr>
                        <th>Order Tracking ID</th>
                        <td>' . $transactionResponse["order_tracking_id"] . '</td>
                    </tr>
                    <tr>
                        <th>Merchant Reference</th>
                        <td>' . $transactionResponse["merchant_reference"] . '</td>
                    </tr>
                    <tr>
                        <th>Payment Date</th>
                        <td>' . $transactionResponse["payment_date"] . '</td>
                    </tr>
                    <tr>
                        <th>Next Payment Date</th>
                        <td>' . $transactionResponse["next_payment_date"] . '</td>
                    </tr>
                </table>
                <div>PLEASE CLOSS THE E-PHARMACY SOFTWARE AND RE OPEN</dv>
                <div class="text-center">
                    <a href="#" onclick="confirmClose(); return false;" class="btn">Back to Home</a>
                    <script type="text/javascript">
                        function confirmClose() {
                            // Custom message to ask the user to manually close the window
                            if (confirm(\'Thank you for trusting E-PHARMACY SOFTWARE? Please manually close this tab now.\')) {
                                // You can suggest the user to close the window, but closing will not work in modern browsers.
                                alert("Please close the tab manually.");
                            }
                        }
                    </script>
                </div>
            </div>
        </body>
        </html>';
    } else {
        echo json_encode(["error" => "Invalid response from the API."]);
    }
} else {
    echo json_encode(["error" => "API request failed. Status code: " . $responseCode]);
}
?>

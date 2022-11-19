use Env;
use HTTP::Tiny;
use JSON::Unmarshal;

sub sendTelegramMessage($chatId, $data) {
    my Str $botToken = $TOKEN;
    my $telegramApiUrl = "https://api.telegram.org/bot$botToken/sendMessage";

    return HTTP::Tiny.new.post: $telegramApiUrl, content => $data, headers => content-type => "application/json";
}

sub alert($message) {
    for split(",", $TELEGRAM_ALERT_IDS) -> $chatId {
        my $data = qq:to/END/;
\{
    "chat_id": "$chatId",
    "text": "$message"
}
END

        sendTelegramMessage($chatId, $data)
    }
}

multi fail($prefix, Hash $response) {
    my $content = "";
    if $response<content> {
        $content = "\n{$response<content>.decode}";
    }

    fail("$prefix: $response<status> $response<reason>$content");
}

multi fail(Str $errorMessage) {
    say $errorMessage;
    alert($errorMessage);
    exit(1);
}

sub requiredEnv($name, $value) {
    if $value === "" {
        fail("")
    }
}

requiredEnv("TOKEN", $TOKEN);
requiredEnv("NOTIFIER_IDS", $NOTIFIER_IDS);
requiredEnv("BASE_URL", $BASE_URL);

enum Feature <temperature booking>;

class Lake {
    has Str $.id;
    has Str $.name;
    has Array[Feature] $.supportedFeatures;
}

class LakeResponse {
    has Array[Lake] $.lakes;
}

class TemperatureItem {
    has Str $.time;
    has Int $.temperature;
    has Str $.preciseTemperature;
}

my $response = HTTP::Tiny.new.get: "https://$BASE_URL/lake";

fail("failed to retrieve lakes", $response) unless $response<success>;

my $content = $response<content>.decode;
my LakeResponse $lakes = unmarshal($content, LakeResponse);


my @messageItems = ();
# filter lakes for feature: temperature
for $lakes.lakes -> $lake {
    my $url = "https://$BASE_URL/lake/{$lake.id}/temperature?precision=2";
    my $response = HTTP::Tiny.new.get: $url;
    fail("failed to retrieve {$lake.name} temperature", $response) unless $response<success>;

    my $content = $response<content>.decode;
    my TemperatureItem $item = unmarshal($content, TemperatureItem);

    @messageItems.push: "{$lake.name} hat eine Temperatur von {$item.preciseTemperature}°C";
}

my $text = join("\n", @messageItems);

for split(",", $NOTIFIER_IDS) -> $chatId {
    my $data = qq:to/END/;
\{
    "chat_id": "$chatId",
    "text": "$text"
}
END
    $response = sendTelegramMessage($chatId, $data);
    fail("failed sendMessage to telegram", $response) unless $response<success>;
}

use Env;
use HTTP::Tiny;
use JSON::Unmarshal;

enum Feature <temperature tides>;

class Lake {
    has Str $.id;
    has Str $.name;
    has Array $.features;
}

class LakeResponse {
    has Array[Lake] $.lakes;
}

class TemperatureItem {
    has Str $.time;
    has Int $.temperature;
    has Str $.preciseTemperature;
}

class TideInformation {
    has Bool $.isHighTide;
    has Str $.time;
    has Str $.height;
}

class TideResponse {
    has Array[TideInformation] $.extrema;
}

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

sub isOldTemperature(TemperatureItem $item) {
    my $dt = DateTime.new($item.time);
    my $now = DateTime.now.utc;
    my $diffInSeconds = $now - $dt;

    # older than 24 hours
    return $diffInSeconds > 86400;
}

sub getStartOfDay() {
    return DateTime.now().utc.truncated-to("day");
}

sub getTideInformation(Lake $lake) {
    my $sod = getStartOfDay();
    my $url = "https://$BASE_URL/lake/{$lake.id}/tides?upcomingLimit=4\&at={$sod}";
    my $response = HTTP::Tiny.new.get: $url;
    fail("failed to retrieve {$lake.name} temperature", $response) unless $response<success>;

    my $content = $response<content>.decode;
    return unmarshal($content, TideResponse);
}

sub containsFeature(Lake $lake, Str $feature) {
    my @features = $lake.features;
    for @features -> $feat {
        if $feature.contains($feat) {
            return True;
        }
    }

    return False;
}

requiredEnv("TOKEN", $TOKEN);
requiredEnv("NOTIFIER_IDS", $NOTIFIER_IDS);
requiredEnv("BASE_URL", $BASE_URL);

my $response = HTTP::Tiny.new.get: "https://$BASE_URL/lake";

fail("failed to retrieve lakes", $response) unless $response<success>;

my $content = $response<content>.decode;
my LakeResponse $lakeResponse = unmarshal($content, LakeResponse);
my @lakes = $lakeResponse.lakes;

my @messageItems = ();

@messageItems.push: "Aktuelle Wassertemperaturen:\n";
for @lakes -> $lake {
    my $url = "https://$BASE_URL/lake/{$lake.id}/temperature?precision=2\&formatRegion=DE";
    my $response = HTTP::Tiny.new.get: $url;
    fail("failed to retrieve {$lake.name} temperature", $response) unless $response<success>;

    my $content = $response<content>.decode;
    my TemperatureItem $item = unmarshal($content, TemperatureItem);
    my Bool $supportsTides = containsFeature($lake, "tides");

    if isOldTemperature($item) && !$supportsTides {
        say "Skipping {$lake.name} due to the timestamp being too old - {$item.time}"
    } else {
        if !isOldTemperature($item) {
            @messageItems.push: "{$lake.name} {$item.preciseTemperature}°C";
        }
        if $supportsTides {
            my $tideInformation = getTideInformation($lake);
            my $*TZ = 3600;
            for $tideInformation.extrema.tail(4) -> $info {
                my $time = DateTime.new($info.time, formatter => {sprintf "%02d:%02d (%02d.%02d)", .hour, .minute, .day, .month}).local;
                my Str $tideModifier = "NW";
                if $info.isHighTide {
                    $tideModifier = "HW";
                }
                @messageItems.push: "        {$time} {$tideModifier}";
            }
        }
    }
}

my $text = join("\n", @messageItems);
if $text === "Aktuelle Wassertemperaturen:" {
    fail("fail: no message content")
}

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

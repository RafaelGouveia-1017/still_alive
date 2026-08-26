CREATE TABLE
    settings (key VARCHAR(200) PRIMARY KEY, value TEXT NOT NULL);

INSERT INTO
    settings
VALUES
    ('tutorial', 'true'),
    ('theme', 'SmartBell'),
    ('lang', 'en'),
    ('location', 'true'),
    ('route', 'true'),
    ('microphone', 'true'),
    ('lock', 'true'),
    ('volume', '100'),
    ('message', '');

CREATE TABLE
    contacts (
        key VARCHAR(200) PRIMARY KEY,
        value TEXT NOT NULL CHECK (json_valid (value))
    );

/*
quick:
{
"count": 0,
"ids": [] // list of contact ids
}
emergency:
{
"count": 0,
"ids": [] // list of contact ids
}
preferences:
{
"count": 1,
"contacts": [ // list with contact id & its prefs
{
"id": "example",
"sms": true,
"email": true,
"location": true,
"audio": true
}
]
}
 */
INSERT INTO
    contacts
VALUES
    ('quick', '{"count": 0, "ids": []}'),
    ('emergency', '{"count": 0, "ids": []}'),
    ('preferences', '{"count": 0, "contacts": []}');

CREATE TABLE
    history (
        created_at DATE PRIMARY KEY DEFAULT CURRENT_DATE,
        value TEXT NOT NULL CHECK (json_valid (value))
    );

/*
{
"count": 5,
"events": [
{
"type": "started",
"timer_name": "Walk Home",
"started_at": "2023-05-12T11:00:00.000",
"ended_at": null,
"details": {
"duration_seconds": 1800,
"grace_period_seconds": 60,
"password_protected": true
}
},
{
"type": "warning",
"timer_name": "Walk Home",
"started_at": "2023-05-12T00:00:00.000",
"ended_at": "2023-05-12T11:00:00.000",
"details": {
"remaining_seconds": 60
}
},
{
"type": "paused",
"timer_name": "Walk Home",
"started_at": "2023-05-12T00:00:00.000",
"ended_at": "2023-05-12T11:00:00.000",
"details": {
"remaining_seconds": 542,
"password_verified": true
}
},
{
"type": "cancelled",
"timer_name": "Walk Home",
"started_at": "2023-05-12T00:00:00.000",
"ended_at": "2023-05-12T11:00:00.000",
"details": {
"remaining_seconds": 542,
"password_verified": true
}
},
{
"type": "expired",
"timer_name": "Walk Home",
"started_at": "2023-05-12T00:00:00.000",
"ended_at": "2023-05-12T11:00:00.000",
"details": {
"location": {
"latitude": 38.7369,
"longitude": -9.1427
},
"polyline": "null or big string with GPS points that somehow occupies less space",
"sms": [
{
"recipient": "+351912345678",
"status": "sent"
},
{
"recipient": "+351987654321",
"status": "failed"
}
],
"emails": [
{
"recipient": "john@example.com",
"status": "sent"
}
],
"channels": [
{
"platform": "Telegram",
"status": "sent"
},
{
"platform": "Discord",
"status": "sent"
}
],
"alarm_triggered": true,
"audio_recorded": false
}
}
]
}
 */
CREATE TRIGGER cleanup_old_history AFTER INSERT ON history BEGIN
DELETE FROM history
WHERE
    created_at < date ('now', '-6 month');

END;

CREATE TABLE
    integrations (
        key VARCHAR(200) PRIMARY KEY,
        value TEXT NOT NULL CHECK (json_valid (value))
    );

/*
discord:
{
"accounts": [
{
"id": "example",
"name": "Vorso",
"app_id": "example",
"destinations": [
{
"id": "789",
"name": "general",
"kind": "server_channel",
"parent_id": "5KuCjeIJNd",
"parent_name": "Still Alive"
},
{
"id": "0GoH5qOT3D",
"name": "music",
"kind": "server_channel",
"parent_id": "rnvqTfEQKs",
"parent_name": "Monstercat"
},
{
"id": "dAE1KqF4YI",
"name": "Alice",
"kind": "direct_message",
"parent_id": null,
"parent_name": null
}
]
}
]
}
telegram:
{
"accounts": [
{
"id": "example",
"name": "Thomas",
"update_offset": 2,
"destinations": [
{
"id": "hf77hRua6d",
"name": "Tom",
"kind": "direct_message",
"parent_id": null,
"parent_name": null
},
{
"id": "45J44CGdTb",
"name": "Still Alive",
"kind": "group",
"parent_id": null,
"parent_name": null
}
]
}
]
}
 */
INSERT INTO
    integrations (key, value)
VALUES
    ('discord', '{"accounts": []}'),
    ('telegram', '{"accounts": []}');

CREATE TABLE
    timers (
        key VARCHAR(200) PRIMARY KEY,
        value TEXT NOT NULL CHECK (json_valid (value))
    );

/*
{
"name": "Example Timer",
"duration_secs": 10,
"grace_period_secs": null,
"password_protected": false,
"password_Hash": null,
"location_sharing_enabled": false,
"route_sharing_enabled": false,
"location_collection_interval_secs": null,
"audio_recording_enabled": false,
"contacts": [
{
"id": "example id",
"sms": [], //list of selected phone numbers
"email": [] //list of selected emails
}
],
"custom_sms": [], //list of custom phone numbers
"custom_email": [], //list of custom emails
"integrations": {
"discord": {
"accounts": [
{
"id": "account id",
"destinations": [] //list of destination ids
}
]
},
"telegram": {
"accounts": [
{
"id": "account id",
"destinations": [] //list of destination ids
}
]
}
},
"created_at": "2023-05-12T11:00:00.000",
"updated_at": "2023-05-12T11:00:00.000"
}
 */
INSERT INTO
    timers (key, value)
VALUES
    (
        'timer0',
        '{
            "name": "Example Timer",
            "duration_secs": 10,
            "grace_period_secs": 5,
            "password_protected": false,
            "password_Hash": null,
            "location_sharing_enabled": false,
            "route_sharing_enabled": false,	 
            "location_collection_interval_secs": null,
            "audio_recording_enabled": false,
            "contacts": [],
            "custom_sms": [],
            "custom_email": [],
            "integrations": {
                "discord": {
                    "accounts": []
                },
                "telegram": {
                    "accounts": []
                }
            },
            "created_at": "2023-05-12T11:00:00.000",
            "updated_at": "2023-05-12T11:00:00.000"
        }'
    );

CREATE TRIGGER cleanup_deleted_integration_destinations AFTER
UPDATE OF value ON integrations BEGIN
UPDATE timers
SET
    value = json_set (
        value,
        '$.integrations.' || NEW.key || '.accounts',
        (
            SELECT
                COALESCE(
                    json_group_array (
                        json_set (
                            timer_account.value,
                            '$.destinations',
                            (
                                SELECT
                                    COALESCE(
                                        json_group_array (timer_destination.value),
                                        json ('[]')
                                    )
                                FROM
                                    json_each (
                                        json_extract (timer_account.value, '$.destinations')
                                    ) AS timer_destination
                                WHERE
                                    EXISTS (
                                        SELECT
                                            1
                                        FROM
                                            json_each (json_extract (NEW.value, '$.accounts')) AS integration_account
                                        WHERE
                                            json_extract (integration_account.value, '$.id') = json_extract (timer_account.value, '$.id')
                                            AND EXISTS (
                                                SELECT
                                                    1
                                                FROM
                                                    json_each (
                                                        json_extract (integration_account.value, '$.destinations')
                                                    ) AS integration_destination
                                                WHERE
                                                    json_extract (integration_destination.value, '$.id') = timer_destination.value
                                            )
                                    )
                            )
                        )
                    ),
                    json ('[]')
                )
            FROM
                json_each (
                    json_extract (
                        value,
                        '$.integrations.' || NEW.key || '.accounts'
                    )
                ) AS timer_account
            WHERE
                EXISTS (
                    SELECT
                        1
                    FROM
                        json_each (json_extract (NEW.value, '$.accounts')) AS integration_account
                    WHERE
                        json_extract (integration_account.value, '$.id') = json_extract (timer_account.value, '$.id')
                )
        )
    )
WHERE
    json_extract (value, '$.integrations.' || NEW.key) IS NOT NULL;

END;
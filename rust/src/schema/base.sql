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
    contacts (key VARCHAR(200) PRIMARY KEY, value TEXT NOT NULL);

INSERT INTO
    contacts
VALUES
    ('quick', '{"count": 0, "ids": []}'),
    ('emergency', '{"count": 0, "ids": []}'),
    (
        'preferences',
        '{"count": 1, "contacts": [{"id": "example", "sms": true, "email": true, "location": true, "audio": true}]}'
    );

CREATE TABLE
    history (
        created_at DATE PRIMARY KEY DEFAULT CURRENT_DATE,
        value TEXT NOT NULL
    );

INSERT INTO
    history
VALUES
    (
        date ('now', '-1 year'),
        '{"count": 5, "events": [
        {"type": "started", "severity": "primary", "timer_name": "Walk Home", "started_at": "2023-05-12T11:00:00.000", "ended_at": null, "details": { "duration_seconds": 1800, "grace_period_seconds": 60, "password_protected": true }},
        {"type": "warning", "severity": "warning", "timer_name": "Walk Home", "started_at": "2023-05-12T00:00:00.000", "ended_at": "2023-05-12T11:00:00.000", "details": { "remaining_seconds": 60 }},
        {"type": "paused", "severity": "muted", "timer_name": "Walk Home", "started_at": "2023-05-12T00:00:00.000", "ended_at": "2023-05-12T11:00:00.000", "details": { "remaining_seconds": 542, "password_verified": true }},
        {"type": "cancelled", "severity": "safe", "timer_name": "Walk Home", "started_at": "2023-05-12T00:00:00.000", "ended_at": "2023-05-12T11:00:00.000", "details": { "remaining_seconds": 542, "password_verified": true }},
        {"type": "expired", "severity": "danger", "timer_name": "Walk Home", "started_at": "2023-05-12T00:00:00.000", "ended_at": "2023-05-12T11:00:00.000", "details": { 
            "location": { "latitude": 38.7369, "longitude": -9.1427 }, 
            "polyline": "null or big string with GPS points that somehow occupies less space", 
            "sms": [{ "recipient": "+351912345678", "status": "sent" }, {"recipient": "+351987654321", "status": "failed" }],
            "emails": [{ "recipient": "john@example.com", "status": "sent" }],
            "channels": [{ "platform": "Telegram", "status": "sent" }, { "platform": "Discord", "status": "sent" }],
            "alarm_triggered": true,
            "audio_recorded": false
        }}
        ]}'
    );

CREATE TRIGGER cleanup_old_history AFTER INSERT ON history BEGIN
DELETE FROM history
WHERE
    created_at < datetime ('now', '-3 month');

END;

CREATE TABLE
    integrations (key VARCHAR(200) PRIMARY KEY, value TEXT NOT NULL);

INSERT INTO
    integrations (key, value)
VALUES
    (
        'discord',
        '{
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
        }'
    ),
    (
        'telegram',
        '{
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
        }'
    );
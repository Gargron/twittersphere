Twittersphere
=============

A thing that fetches user connections from Twitter and exports them to a GDF (directed graph file) that can be used e.g. in Gephi. Uses Dotenv (or well, environment variables) for Twitter API details (you need to have a registered application). Example `.env` file:

    TW_CONSUMER_KEY: foo
    TW_CONSUMER_SECRET: foo
    TW_ACCESS_TOKEN: foo
    TW_ACCESS_TOKEN_SECRET: foo

Installing is easy after you clone/download this repository:

    bundle install

Usage:

    ./bin/twis fetch Gargron
    ./bin/twis process Gargron
    ./bin/twis inspect

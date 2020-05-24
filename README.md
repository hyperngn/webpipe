# WebPipe

WebPipe allows you to pipe from your servers to the browser!

## Screenshots

![Screenshot of WebPipe](./webpipe-screenshot.png)

## Usage

You can spin it up by running the following command if you have a working
version of Elixir:

```
iex -S mix
```

If you don't have Elixir you can build a docker container and run it in a
container via the following commands:

```
# build the image
docker build -t webpipe:latest .
# run the image
docker run webpipe:latest
```

Once you boot up the docker container, webpipe should be available on the docker
container's IP on port 8000.

You can use the following command to find the IP address of your webpipe
container:

```
docker inspect  -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container_name>
```

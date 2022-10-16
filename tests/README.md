This directory lets you test Lambda layers using Docker, either automatically or manually.

**First, build the layers.**

Then, run the automated tests:

```bash
make test
```

To test the layers manually (for example to troubleshoot something), start the containers:

```bash
make run
```

In another terminal, send test requests:

```bash
make test-function
make test-fpm
```

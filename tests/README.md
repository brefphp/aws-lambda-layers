This directory lets you test the runtime images using Docker, either automatically or manually.

**First, build the images.**

Then, run the automated tests:

```bash
make test
```

To test the images manually (for example to troubleshoot something), start the containers:

```bash
make run
```

In another terminal, send test requests:

```bash
make test-function
make test-fpm
```

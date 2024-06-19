docker build -t jupyter-typescript . && docker run -p 8889:8888 -v $(pwd):/app jupyter-typescript

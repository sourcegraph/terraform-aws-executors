# Docker registry mirror

These terraform files represent a sibling deployment to executors that acts as a
shared write-through Docker image cache. Executor deployments should be configured
to point to this deployment in order to prevent rate limiting of requests from a
public Docker registry and to increase bandwidth while pulling images.

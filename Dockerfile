# -------------------------------------------------------------------------
# What: Tell Docker how to build our application using multi-stage builds
# Why:  1) keep image small by discarding build tools and dev dependencies.
#       2) leverage Docker’s layer caching to speed up builds.
#       3) follow best practices for deploying with Docker
#
# NOTES:
#   1) We should install our dependencies as devDependencies, so that 
#      SvelteKit can bundle them in our app and discard unused imports.
#   2) During the build step, if we get any errors we may need to move 
#      some dependencies to be non-dev dependencies.
#   3) If all our dependencies can be devDependencies, we don’t need to 
#      ship node_modules at all.
# -------------------------------------------------------------------------
ARG VERSION=22

# NOTE: For Apple Silicon (Mx macs), comment the lock argument to mitigate 
# npm bug (https://github.com/npm/cli/issues/4828). See additional notes 
# below.
# ARG LOCK=--frozen-lockfile

# -------------------------------------------------------------------------
# What: Stage 0
# Why:  Set up our base layer using the latest node image with pnpm
FROM node:${VERSION}-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# -------------------------------------------------------------------------
# What: Stage 1
# Why:  Install and build our development files
FROM base AS develop

# Create our workspace and copy in our project source files
WORKDIR /app
COPY . .

# Remove cached files if the LOCK variable is unassigned. Then install
# our dev dependencies and build the project
# NOTE: For Apple Silicon, uncomment the following line
RUN rm -rf node_modules pnpm-lock.yaml
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install ${LOCK}
RUN pnpm run build

# -------------------------------------------------------------------------
# What: Stage 2
# Why:  Set up our build files for production
FROM develop AS compile
RUN pnpm prune --prod

# -------------------------------------------------------------------------
# What: Stage 3
# Why:  Generatte any release dependencies for prod
FROM base AS depends
ENV NODE_ENV=production

# Create our workspace and copy in our project dependency file
WORKDIR /app
COPY package*.json .

# Copy in the lock file if the LOCK variable is assigned. Then install
# our prod dependencies
# NOTE: For Apple Silicon, exclude the lock file copy
# RUN cp pnpm-lock.yaml .
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install ${LOCK} --prod

# -------------------------------------------------------------------------
# What: Stage 3
# Why:  Set up our actual production image
# How:  Using a distroless image, copy our production dependencies and 
#       build files to execute our rootless command.
FROM gcr.io/distroless/nodejs${VERSION}-debian12 AS release
ENV NODE_ENV=production
COPY static .
COPY --from=depends /app/node_modules node_modules/
COPY --from=compile /app/build .

EXPOSE 3000/tcp
CMD ["index.js"]

# What: Using our base image, copy our production dependencies and 
#       build files to configure our endpoint using the node user.
# How:  Copy our production dependencies and build files into final image
# FROM base AS release
# ENV NODE_ENV=production
# USER node
# COPY --chown=node:node --from=depend /app/node_modules node_modules/
# COPY --chown=node:node --from=develop /app/build .
# EXPOSE 3000/tcp
# ENTRYPOINT [ "node", "index.js" ]

# DevOps homework — Anantha

**Name:** Anantha  **Enrollment Number:** _(fill in)_

One folder per topic. Each has its own README with what I did, the commands, the captured output,
and what broke.

| Folder | Topic | Status |
|---|---|---|
| [Linux fundamentals](Linux%20fundamentals/) | links, `adduser` vs `useradd`, journalctl, cheat sheet | all 3 scripts run on Ubuntu 24.04 |
| [Shell Scripting](Shell%20Scripting/) | system information script | run |
| [networking fundamentals](networking%20fundamentals/) | IP addressing, subnetting, ten commands | run |
| [Git-GitHub](Git-GitHub/) | `git commit -a -m`, cherry-pick | run |
| [Docker Fundamentals](Docker%20Fundamentals/) | six Hello World apps in Docker | 6/6 pass |
| [DockerFiles and images](DockerFiles%20and%20images/) | multi-stage builds, layers, three deployments | run |
| [Docker network](Docker%20network/) | networks, host mode, bind mounts, overlay | tasks 1–3 run, task 4 written up |

## Environment

Windows 11, Git Bash. Docker Desktop with the WSL2 backend, Docker Engine 29.7.2. Node 22, Python
3.13, JDK 23 on the host; the containers use Node 20, Python 3.12 and Temurin 21.

Anything that needed real Linux — the links and user-account exercises — was run inside an
`ubuntu:24.04` container rather than described from memory.

## Results at a glance

```
Docker Fundamentals     6 passed, 0 failed        3000, 5000, 8080-8083
DockerFiles and images  multi-stage 199MB vs single-stage 239MB
                        rebuild 2s cached vs 7s invalidated
Docker network          3 networks, 4 containers, connectivity matrix as predicted
Shell Scripting         sysinfo.sh, report written to a folder of your choosing
Git-GitHub              both tasks, in a throwaway repo, plus conflict handling
networking              /20 subnet calculated by hand, confirmed in route print
```

## Ports used, so two folders can run at once

| Range | Folder |
|---|---|
| 3000, 5000, 8080–8083 | Docker Fundamentals |
| 8090–8093 | DockerFiles and images |
| 8180–8183 | Docker network |

## How to run everything

```bash
cd "Docker Fundamentals"     && bash build-and-run.sh   && bash build-and-run.sh down
cd "DockerFiles and images"  && bash run-all.sh         && bash run-all.sh clean
cd "Docker network"          && bash task1-networking.sh; bash task2-host-network.sh; bash task3-bindmount.sh
cd "Git-GitHub"              && bash demo.sh && bash extras.sh
cd "Shell Scripting"         && bash sysinfo.sh
cd "networking fundamentals" && bash subnet-practice.sh 192.168.1.100/26
cd "Linux fundamentals"      && bash practice/01-links-practice.sh
```

Every Docker script takes a `clean` or `down` argument that removes what it created.

## A note on the output files

The captures in each `output/` folder are real runs on this machine, including the ones that
failed. Two of them are kept deliberately because the failure was the lesson:

- `DockerFiles and images/output/bug-head-shadowing.txt` — a run where a shell function named
  `head()` silently replaced `/usr/bin/head` in the same script.
- `Docker Fundamentals/output/experiment-loopback.txt` — a container bound to `127.0.0.1` instead
  of `0.0.0.0`, showing exactly what that looks like from the outside (everything green, nothing
  answers).

MAC addresses in the networking captures were masked before committing; the reasoning is in that
folder's README.

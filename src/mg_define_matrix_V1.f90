module mg_operators

  use mg_mpi
  use mg_tictoc
  use mg_namelist
  use mg_grids
  use mg_mpi_exchange
  use mg_gather

  implicit none

contains
  !-------------------------------------------------------------------------     
  subroutine Kinetic_energy(u,v,w,uf,vf,wf);

    real(kind=rp)   :: dimension(:,:,:),intent(in):: u,v,w
    real(kind=rp)   :: dimension(:,:,:),intent(in):: uf,vf,wf

    real(kind=rp)    :: Ek = 0.0_8
    integer(kind=ip) :: i,j,k

 
    do i = 1,nx
       do j = 1,ny
          do k = 1,nz
              Ek = Ek + 
   &            0.5*( u(k,j,i  )*uf(k,j,i  )*dxu(j,i  )*dyu(j,i  )*dzu(k,j,i  ) + 
   &                  u(k,j,i+1)*uf(k,j,i+1)*dxu(j,i+1)*dyu(j,i+1)*dzu(k,j,i+1) ) + 
   &            0.5*( v(k,j  ,i)*vf(k,j  ,i)*dxv(j  ,i)*dyv(j  ,i)*dzv(k,j  ,i) + 
   &                  v(k,j+1,i)*vf(k,j+1,i)*dxv(j+1,i)*dyv(j+1,i)*dzv(k,j+1,i) ) + 
   &            0.5*( w(k  ,j,i)*wf(k  ,j,i)*dx(j,i)*dy(j,i)*dzw(k  ,j,i) + 
   &                  w(k+1,j,i)*wf(k+1,j,i)*dx(j,i)*dy(j,i)*dzw(k+1,j,i) ) + 
          enddo
       enddo
    enddo

  end subroutine Kinetic Energy
!----------------------------------------
  subroutine Momentum2flux(u,v,w,uf,vf,wf,zx)
    !!
    !!  uf =  um - wm*zx
    !!  vf =  vm - wm*zy
    !!  wf = -zx*um - zx*vm + (1+zx^2+ zy^2)*wm
    !!
    real(kind=rp)   :: dimension(:,:,:),intent(in) :: u,v,w
    real(kind=rp)   :: dimension(:,:,:),intent(out):: uf,vf,wf
    real(kind=rp)   :: dimension(:,:,:),intent(in) :: zx

    !! Slopes are defined at rho-points
    do i = 1,nx+1
       do j = 1,ny
          do k = 1,nz
            uf(k,j,i) = um(k,j,i) - 0.25*(zx(k,j,i  )*wm(k,j,i  ) + zx(k,j,i  )*wm(k+1,j,i  )
                                          zx(k,j,i-1)*wm(k,j,i-1) + zx(k,j,i-1)*wm(k+1,j,i-1) )
            vf(k,j,i) = vm(k,j,i) - 0.25*(zy(k,j  ,i)*wm(k,j  ,i) + zx(k,j  ,i)*wm(k+1,j  ,i)
                                          zy(k,j-1,i)*wm(k,j-1,i) + zx(k,j  ,i)*wm(k+1,j  ,i) )
            wf(k,j,i) = vm(k,j,i) - 0.25*(zy(k,j  ,i)*wm(k,j  ,i) + zx(k,j  ,i)*wm(k+1,j  ,i)
                                          zy(k,j-1,i)*wm(k,j-1,i) + zx(k,j  ,i)*wm(k+1,j  ,i) )
       enddo
       zw(nz+1,j,i) = 0.0
    enddo

  end subroutine Momentum2flux
!----------------------------------------
  subroutine define_matrix(lev)

    integer(kind=ip),intent(in):: lev

    ! Define matrix coefficients cA
    ! Coefficients are stored in order of diagonals
    ! cA(1,:,:,:)      -> p(k,j,i)
    ! cA(2,:,:,:)      -> p(k-1,j,i)
    ! cA(3,:,:,:)      -> p(k+1,j-1,i)
    ! cA(4,:,:,:)      -> p(k,j-1,i)
    ! cA(5,:,:,:)      -> p(k-1,j-1,i)
    ! cA(6,:,:,:)      -> p(k+1,j,i-1)
    ! cA(7,:,:,:)      -> p(k,j,i-1)xd
    ! cA(8,:,:,:)      -> p(k-1,j,i-1)

    real(kind=rp), dimension(:,:,:,:), pointer :: cA
    integer(kind=ip):: k, j, i
    real(kind=rp):: dxi, dyi, dzi
    integer(kind=ip):: nx, ny, nz
    integer(kind=ip):: nh

    real(kind=rp):: dimension(:,:,:),allocatable :: dz
    real(kind=rp):: dimension(:,:,:),allocatable :: dzw
    real(kind=rp):: dimension(:,:,:),allocatable :: zydx,zxdy


    !!! I'm assuming that I'm getting zw,zr,dx,dy from outside this routine

    nx = grid(lev)%nx
    ny = grid(lev)%ny
    nz = grid(lev)%nz
    nh = grid(lev)%nh
    cA => grid(1)%cA 


!!!  I need to know my global index range
    do i = 0,nx+1
       do j = 0,ny+1
          h(j,i) = 4000 - 2000.*exp(-r2)
       enddo
    enddo

    allocate(zr(nz,ny,nx))
    allocate(zw(nz+1,ny,nx))
    do i = 0,nx+1
       do j = 0,ny+1
          do k = 1,nz
            zr(k,j,i) = (k-0.5)*h(j,i)/nz - h(j,i)
            zw(k,j,i) = (k-1.0)*h(j,i)/nz - h(j,i)
       enddo
       zw(nz+1,j,i) = 0.0
    enddo

    do i = 1,nx
       do j = 1,ny
          do k = 1,nz
             dz(k,j,i) = zw(k+1,j,i)-zw(k,j,i)     !!  cell height at rho-points
          enddo
       enddo
    enddo

    allocate(dxu(ny,nx+1)
    do i = 1,nx+1
       do j = 1,ny
          dxu(j,i) = 0.5*(dx(j,i) + dx(j,i-1))
       enddo
    enddo
    allocate(dyv(ny+1,nx)
    do i = 1,nx
       do j = 1,ny+1
          dyv(j,i) = 0.5*(dy(j,i) + dy(j-1,i))
       enddo
    enddo

    allocate(Ary(nz,ny,nx+1))
    do i = 1,nx+1
       do j = 1,ny
          do k = 1,nz
            Arx(k,j,i) = 0.25*(dz(k,j,i)+dz(k,j,i-1))*(dy(j,i)+dy(j,i-1)) 
          enddo
       enddo
    enddo
    allocate(Ary(nz,ny+1,nx))
    do i = 1,nx
       do j = 1,ny+1
          do k = 1,nz
            Ary(k,j,i) = 0.25*(dz(k,j,i)+dz(k,j-1,i))*(dx(j,i)+dx(j-1,i)) 
          enddo
       enddo
    enddo
    allocate(Arz(ny,nx))
    do i = 1,nx
       do j = 1,ny
          Arz(j,i) =  dx(j,i)*dy(j,i)
       enddo
    enddo

    !!  Slope in y-direction multiplied by dx defined at rho-points
    !!  Slope in x-direction multiplied by dy defined at rho-points
    allocate(zxdy(nz,ny,nx))
    allocate(zydx(nz,ny,nx))
    do i = 1,nx
       do j = 1,ny
          do k = 1,nz
            zydx(k,j,i) = 0.5*(zr(k,j+1,i)-zw(k,j-1,i))*dx(j,i)/dy(j,i)
            zxdy(k,j,i) = 0.5*(zr(k,j,i+1)-zw(k,j,i-1))*dy(j,i)/dx(j,i)
          enddo
       enddo
    enddo
    allocate(zyw(nz+1,ny,nx))
    allocate(zxw(nz+1,ny,nx))
    do i = 1,nx
       do j = 1,ny
          do k = 1,nz+1
            zyw(k,j,i) = 0.5*(zw(k,j+1,i)-zw(k,j-1,i))*/dy(j,i)
            zxw(k,j,i) = 0.5*(zw(k,j,i+1)-zw(k,j,i-1))*/dx(j,i)
          enddo
          enddo
       enddo
    enddo

!!  ----------------------------------------------------------------------------------------------------------------
    do i = 1,nx
       do j = 1,ny
          do k = 2,nz
             cA(2,k,j,i) = Arz(j,i)/dzw(k,j,i)*(1+zxw(k,j,i)*zxw(k,j,i)+zyw(k,j,i)*zyw(k,j,i)) !! couples with k-1
             cA(3,k,j,i) = 0.25*zydx(k+1,j,i)+0.25*zydx(k,j-1,i)                               !! couples with k+1 j-1
             cA(4,k,j,i) = Ary(k,j,i)/dyv(j,i)                                                 !! couples with j-1
             cA(5,k,j,i) =-0.25*zydx(k-1,j,i)-0.25*zydx(k,j-1,i)                               !! couples with k-1 j-1
             cA(6,k,j,i) = 0.25*zxdy(k+1,j,i)+0.25*zxdy(k,j,i-1)                               !! Couples with k+1 i-1
             cA(7,k,j,i) = Arx(k,j,i)/dxu(j,i)                                                 !! Couples with i-1
             cA(8,k,j,i) =-0.25*zxdy(k-1,j,i)-0.25*zxdy(k,j,i-1)                               !! Couples with k-1 i-1
          enddo
          k = nz
          cA(4,k,j,i) = cA(4,k,j,i) - 0.25*zydx(k,j-1,i) + 0.25*zydx(k,j,i)
          cA(7,k,j,i) = cA(7,k,j,i) - 0.25*zxdy(k,j,i-1) + 0.25*zxdy(k,j,i)
       enddo
    enddo
    !! Bottom level. 
    k = 1
    do i = 1,nx
       do j = 1,ny
          cA(1,k,j,i) = -0.5*Arz(j,i)/dzw(k,j,i)*(1+zxw(k,j,i)*zxw(k,j,i)+zyw(k,j,i)*zyw(k,j,i))
          cA(2,k,j,i) =  0.5*Arz(j,i)/dzw(k,j,i)*(1+zxw(k,j,i)*zxw(k,j,i)+zyw(k,j,i)*zyw(k,j,i))
          cA(3,k,j,i) =  0.25*zydx(k,j,i)
          cA(5,k,j,i) = -0.25*zydx(k,j,i)
          cA(6,k,j,i) =  0.25*zxdy(k,j,i)
          cA(8,k,j,i) = -0.25*zxdy(k,j,i)
       enddo
    enddo
    do i = 1,nx
       do j = 1,ny
          do k = 2,nz-1
             cA(1,k,j,i) = -cA(2,k,j,i)- cA(2,k+1,j,i)-cA(4,k,j,i)- cA(4,k,j+1,i)-cA(7,k,j,i)- cA(7,k,j,i+1)
          enddo
          k = nz
          cA(1,k,j,i) = -cA(2,k,j,i)- 2*cA(2,k+1,j,i)-cA(4,k,j,i)- cA(4,k,j+1,i)-cA(7,k,j,i)- cA(7,k,j,i+1)
       enddo
    enddo
    !!
    !!! For the moment, we will implement side bc by means of a buffer. The next phase will include a mask, whereupon we must
    !! implement horizontal condition in the matrix coefficients

    !! West Boundary 
    i = 1
    do j = 1,ny
       do k = 1,nz
!         cA(2,k,j,i) = Arz(j,i)/dzw(k,j,i)*(1+0.5*zxw(k,j,i)*zxw(k,j,i)+zyw(k,j,i)*zyw(k,j,i)) !! couples with k-1
       enddo
    enddo
    do j = 1,ny
       do k = 1,nz
!         cA(1,k,j,i) = -cA(2,k,j,i)- cA(2,k+1,j,i)-cA(4,k,j,i)- cA(4,k,j+1,i)-cA(7,k,j,i+1)
!         cA(2,k,j,i) = cA(2,k,j,i) - 0.25*zxdy(k-1,j,i) + 0.25*zxdy(k,j,i)
       enddo
    enddo
    !! East Boundary 
    i = nx
    do j = 1,ny
       do k = 1,nz
!         cA(2,k,j,i) = Arz(j,i)/dzw(k,j,i)*(1+0.5*zxw(k,j,i)*zxw(k,j,i)+zyw(k,j,i)*zyw(k,j,i)) !! couples with k-1
! &                   + 0.25*zxdy(k-1,j,i) - 0.25*zxdy(k,j,i)
       enddo
    enddo
    !! South Boundary 
    j = 1
    do i = 1,nx
       do k = 1,nz
!         cA(2,k,j,i) = Arz(j,i)/dzw(k,j,i)*(1+zxw(k,j,i)*zxw(k,j,i)+0.5*zyw(k,j,i)*zyw(k,j,i)) !! couples with k-1
! &                   - 0.25*zydx(k-1,j,i) + 0.25*zydx(k,j,i)
       enddo
    enddo
    !! North Boundary 
    j = ny
    do i = 1,nx
       do k = 1,nz
!         cA(2,k,j,i) = Arz(j,i)/dzw(k,j,i)*(1+zxw(k,j,i)*zxw(k,j,i)+0.5*zyw(k,j,i)*zyw(k,j,i)) !! couples with k-1
! &                   + 0.25*zydx(k-1,j,i) - 0.25*zydx(k,j,i)
       enddo
    enddo

    deallocate(Arx)
    deallocate(Ary)
    deallocate(Arz)
    deallocate(zxdy)
    deallocate(zydx)
    

  end subroutine define_matrix
  !----------------------------------------
  subroutine define_matrix_simple(lev)

    integer(kind=ip),intent(in):: lev

    ! Define matrix coefficients cA
    ! Coefficients are stored in order of diagonals
    ! cA(1,:,:,:)      -> p(k,j,i)
    ! cA(2,:,:,:)      -> p(k-1,j,i)
    ! cA(3,:,:,:)      -> p(k+1,j-1,i)
    ! cA(4,:,:,:)      -> p(k,j-1,i)
    ! cA(5,:,:,:)      -> p(k-1,j-1,i)
    ! cA(6,:,:,:)      -> p(k+1,j,i-1)
    ! cA(7,:,:,:)      -> p(k,j,i-1)xd
    ! cA(8,:,:,:)      -> p(k-1,j,i-1)

    real(kind=rp), dimension(:,:,:,:), pointer :: cA
    integer(kind=ip):: k, j, i
    real(kind=rp):: dxi, dyi, dzi
    integer(kind=ip):: nx, ny, nz
    integer(kind=ip):: nh

    nx = grid(lev)%nx
    ny = grid(lev)%ny
    nz = grid(lev)%nz
    nh = grid(lev)%nh

    cA => grid(1)%cA ! check the syntax / lighten the writing

    dxi=1._8   !/dx
    dyi=1._8   !/dy
    dzi=1._8*16   !/dz

    !extended loops will be a pain for the real matrix
    do i = 1-nh,nx+nh
       do j = 1-nh,ny+nh
          do k = 1,nz
! --- regular 7 points Laplacian ---
!!$             cA(1,k,j,i) = 2._8*(-dxi*dxi-dyi*dyi-dzi*dzi)
!!$             cA(2,k,j,i) = dzi*dzi
!!$             cA(3,k,j,i) = 0.0_8
!!$             cA(4,k,j,i) = dyi*dyi
!!$             cA(5,k,j,i) = 0.0_8
!!$             cA(6,k,j,i) = 0.0_8
!!$             cA(7,k,j,i) = dxi*dxi
!!$             cA(8,k,j,i) = 0.0_8

! --- extended stencil with diagonal coupling: better convergence rate ---
             cA(1,k,j,i) = 2._8*(-dxi*dxi-dyi*dyi-dzi*dzi)-4*(dxi*dzi+dyi*dzi)
             cA(2,k,j,i) = dzi*dzi
             cA(3,k,j,i) = 0.5*dyi*dzi
             cA(4,k,j,i) = dyi*dyi
             cA(5,k,j,i) = 0.5*dyi*dzi
             cA(6,k,j,i) = 0.5*dxi*dzi
             cA(7,k,j,i) = dxi*dxi
             cA(8,k,j,i) = 0.5*dxi*dzi
          enddo
          cA(1,nz,j,i) = cA(1,nz,j,i) - dzi*dzi 
          cA(1,1,j,i)  = cA(1,1,j,i)  + dzi*dzi 
       enddo
    enddo

  end subroutine define_matrix_simple

  !-------------------------------------------------------------------------     
  subroutine coarsen_matrix(lev)
    integer(kind=ip),intent(in):: lev

    real(kind=rp),dimension(:,:,:,:),pointer :: Ac
    real(kind=rp),dimension(:,:,:,:),pointer :: Af

    integer(kind=ip) :: nx, ny, nz
    integer(kind=ip) :: l

    nx = grid(lev+1)%nx
    ny = grid(lev+1)%ny
    nz = grid(lev+1)%nz

    ! the matrix on the fine grid
    Af => grid(lev)%cA

    if (grid(lev+1)%gather == 1) then
       Ac => grid(lev+1)%cAdummy
       nx = grid(lev+1)%nx / grid(lev+1)%ngx
       ny = grid(lev+1)%ny / grid(lev+1)%ngy
!       if(myrank == 0) write(*,*)"gather lev=",lev+1,"nx,ny,nz=",nx,ny,nz
    else
       Ac => grid(lev+1)%cA
!       if(myrank == 0) write(*,*)"F2C   lev=",lev+1,"nx,ny,nz=",nx,ny,nz
    endif


    if ((aggressive).and.(lev==1)) then
!       call coarsen_matrix_aggressive(lev)

    elseif (grid(lev+1)%nz == 1) then
       call coarsen_matrix_2D(Af,Ac,nx,ny,nz)
       ! fill the halo
       do l=1,3
          grid(lev+1)%r = grid(lev+1)%cA(l,:,:,:)
          call fill_halo(lev+1,grid(lev+1)%r)
          grid(lev+1)%cA(l,:,:,:) = grid(lev+1)%r
       enddo

    else
       call tic(lev,'coarsen_matrix_3D')
       call coarsen_matrix_3D(Af,Ac,nx,ny,nz)
       call toc(lev,'coarsen_matrix_3D')
    end if

    if (grid(lev+1)%gather == 1) then
       
       do l=1,8
          grid(lev+1)%dummy3 = Ac(l,:,:,:)
          call gather(lev+1,grid(lev+1)%dummy3,grid(lev+1)%r)
          ! fill the halo
          call fill_halo(lev+1,grid(lev+1)%r)
          grid(lev+1)%cA(l,:,:,:) = grid(lev+1)%r
       enddo
    else
       ! fill the halo
       do l=1,8
          grid(lev+1)%r = grid(lev+1)%cA(l,:,:,:)
          call fill_halo(lev+1,grid(lev+1)%r)
          grid(lev+1)%cA(l,:,:,:) = grid(lev+1)%r
       enddo
    endif


  end subroutine coarsen_matrix

  !-------------------------------------------------------------------------     
  subroutine coarsen_matrix_aggressive(lev)
    integer(kind=ip),intent(in):: lev

    integer(kind=ip) :: idum
    idum = lev

    write(*,*)'Error: coarsen matrix aggressive not available yet !'
    stop -1
  end subroutine coarsen_matrix_aggressive


  !-------------------------------------------------------------------------     
  subroutine coarsen_matrix_2D(cA,cA2,nx2,ny2,nz2) ! from lev to lev+1

    integer(kind=ip):: nx2, ny2, nz2! on lev+1
    real(kind=rp), dimension(:,:,:,:), pointer :: cA,cA2

    integer(kind=ip):: k, j, i
    integer(kind=ip):: km, jm, im
    integer(kind=ip):: k2, j2, i2
    integer(kind=ip):: d

    real(kind=rp)   :: diag,cff


    k = 1
    km= 2
    k2= 1
    ! how many diagonal in the fine matrix? 3 or 8 ?
    d = size(cA,1) 

    ! I'm pretty sure it depends on whether d==3 or d==8

    if (d ==8) then
       cff = 1._8/16._8 ! check this value!!!
        ! fine matrix was 3D
       do i2 = 1,nx2
          i = 2*i2-1
          im = i+1
          do j2 = 1,ny2
             j = 2*j2-1
             jm = j+1     
             ! cA2(2,:,:,:) plays the role of cA(4,:,:,:)
             ! cA2(3,:,:,:) plays the role of cA(7,:,:,:)

             ! TODO: CHECK THESE FORMULA, I'm not completely sure

             cA2(2,k2,j2,i2) = cff*(cA(4,k,j,i)+cA(4,km,j,i)+cA(4,k,j,im)+cA(4,km,j,im))
             cA2(3,k2,j2,i2) = cff*(cA(7,k,j,i)+cA(7,km,j,i)+cA(7,k,jm,i)+cA(7,km,jm,i))
             ! 
             diag = cA(4,k,jm,i)+cA(4,km,jm,i)+cA(4,k,jm,im)+cA(4,km,jm,im)
             diag = cA(7,k,j,im)+cA(7,km,j,im)+cA(7,k,jm,im)+cA(7,km,jm,im) + diag

             diag = diag + diag
             !
             diag = cA(1,k,j,i) +cA(1,km,j,i) +cA(1,k,jm,i) +cA(1,km,jm,i) &
                  +cA(1,k,j,im)+cA(1,km,j,im)+cA(1,k,jm,im)+cA(1,km,jm,im) + diag

             cA2(1,k2,j2,i2) = cff*diag
          enddo
       enddo
    else
       cff = 1._8/4._8 ! check this value!!!
       ! fine matrix was already 2D
       do i2 = 1,nx2
          i = 2*i2-1
          im = i+1
          do j2 = 1,ny2
             j = 2*j2-1
             jm = j+1     
             cA2(2,k2,j2,i2) = cff*(cA(2,k,j,i)+cA(2,k,j,im))
             cA2(3,k2,j2,i2) = cff*(cA(3,k,j,i)+cA(3,k,jm,i))
             ! 
             diag = cA(2,k,jm,i)+cA(2,k,jm,im)
             diag = cA(3,k,jm,i)+cA(3,k,jm,im) + diag
             diag = diag + diag
             diag = cA(1,k,j,i) + cA(1,k,jm,i) + cA(1,k,j,im) + cA(1,k,jm,im) + diag
             cA2(1,k2,j2,i2) = cff*diag
          enddo
       enddo
    endif


  end subroutine coarsen_matrix_2D

  !-------------------------------------------------------------------------     
  subroutine coarsen_matrix_3D(cA,cA2,nx2,ny2,nz2) ! from lev to lev+1

!    integer(kind=ip),intent(in):: lev
    integer(kind=ip):: nx2, ny2, nz2! on lev+1
    real(kind=rp), dimension(:,:,:,:), pointer :: cA,cA2
!    real(kind=rp), dimension(:,:,:) , pointer :: dummy3D

    integer(kind=ip):: k, j, i
    integer(kind=ip):: km, jm, im
    integer(kind=ip):: k2, j2, i2
    integer(kind=ip):: d

    real(kind=rp)   :: diag,cff


!    cA  => grid(lev)%cA
!    cA2 => grid(lev+1)%cA
!    nx2 = grid(lev+1)%nx
!    ny2 = grid(lev+1)%ny
!    nz2 = grid(lev+1)%nz
!    nh  = grid(lev+1)%nh

    ! the coefficients should be rescaled with 1/16
    cff = 1._8/16._8

    do i2 = 1,nx2
       i = 2*i2-1
       im = i+1
       do j2 = 1,ny2
          j = 2*j2-1
          jm = j+1     
          do k2 = 1,nz2
             k = 2*k2-1
             km = k+1
             ! cA(2,:,:,:)      -> p(k-1,j,i)
             cA2(2,k2,j2,i2) = cff*(cA(2,k,j,i)+cA(2,k,jm,i)+cA(2,k,j,im)+cA(2,k,jm,im))
             ! cA(3,:,:,:)      -> p(k+1,j-1,i)
             cA2(3,k2,j2,i2) = cff*(cA(3,k,j,i)+cA(3,k,j,im))
             ! cA(4,:,:,:)      -> p(k,j-1,i)
             cA2(4,k2,j2,i2) = cff*(cA(4,k,j,i)+cA(4,km,j,i)+cA(4,k,j,im)+cA(4,km,j,im))
             ! cA(5,:,:,:)      -> p(k-1,j-1,i)
             cA2(5,k2,j2,i2) = cff*(cA(5,k,j,i)+cA(5,k,j,im))
             ! cA(6,:,:,:)      -> p(k+1,j,i-1)
             cA2(6,k2,j2,i2) = cff*(cA(6,k,j,i)+cA(6,k,jm,i))
             ! cA(7,:,:,:)      -> p(k,j,i-1)
             cA2(7,k2,j2,i2) = cff*(cA(7,k,j,i)+cA(7,km,j,i)+cA(7,k,jm,i)+cA(7,km,jm,i))
             ! cA(8,:,:,:)      -> p(k-1,j,i-1)
             cA2(8,k2,j2,i2) =cff*( cA(8,k,j,i)+cA(8,k,jm,i))

             ! the diagonal term is the sum of 48 terms ...             
             ! why?
             ! easy to see: the coarse cell (call it the box) is made of 8 fine cells
             ! take one fine cell, lay the 15 points on this cell
             ! count how many fine cells within this box are connected to it
             ! you should find 6
             ! multifly that by the number of fine cells

             ! here is the first 20
             diag = cA(2,km,j,i)+cA(2,km,jm,i)+cA(2,km,j,im)+cA(2,km,jm,im)
             diag = cA(3,k,jm,i)+cA(3,k,jm,im)                              + diag
             diag = cA(4,k,jm,i)+cA(4,km,jm,i)+cA(4,k,jm,im)+cA(4,km,jm,im) + diag
             diag = cA(5,km,j,im)+cA(5,km,jm,im)                            + diag
             diag = cA(6,k,j,im)+cA(6,k,jm,im)                              + diag
             diag = cA(7,k,j,im)+cA(7,km,j,im)+cA(7,k,jm,im)+cA(7,km,jm,im) + diag
             diag = cA(8,km,j,im)+cA(8,km,jm,im)                            + diag

             ! double that to account for symmetry of connections, we've now 40 terms
             diag = diag+diag

             ! add the 8 self-interacting terms
             diag = cA(1,k,j,i) +cA(1,km,j,i) +cA(1,k,jm,i) +cA(1,km,jm,i) &
                  +cA(1,k,j,im)+cA(1,km,j,im)+cA(1,k,jm,im)+cA(1,km,jm,im) + diag

             ! here we go!
             cA2(1,k2,j2,i2) = cff*diag
          enddo
       enddo
    enddo

    return

!!$!    if (myrank.eq.0)write(*,*)"coefficients computed"
!!$
!!$    ! fill the halo
!!$    ! the data should be contiguous in memory to use fill_halo 
!!$    ! no need to allocate an extra buffer
!!$    ! use the residual as a dummy variable
!!$    dummy3D => grid(lev+1)%r 
!!$
!!$    !- we should consider a specific fill_halo(4D) -!
!!$
!!$
!!$
!!$    do d = 1,8       
!!$       !!if (myrank.eq.0)write(*,*)"updating halo of coef(",d,",:,:,:)"
!!$       do i2 = 1,nx2
!!$          do j2 = 1,ny2
!!$             do k2 = 1,nz2
!!$                dummy3D(k2,j2,i2) = cA2(d,k2,j2,i2)
!!$             enddo
!!$          enddo
!!$       enddo
!!$
!!$       call fill_halo(lev+1,dummy3D)
!!$
!!$       do i2 = 1-nh,nx2+nh
!!$          do j2 = 1-nh,ny2+nh
!!$             do k2 = 1,nz2
!!$                cA2(d,k2,j2,i2) = dummy3D(k2,j2,i2) * cff
!!$             enddo
!!$          enddo
!!$       enddo
!!$       ! a way of improvement (only if it impacts perfs):
!!$       ! copy from cA2 to dummy3 only the interior ring used to fill the halo
!!$       ! copy from dummy to cA2 only the halo
!!$    enddo

!!$    do d = 1,8       
!!$       if (myrank.eq.0)write(*,*)"updating halo of coef(",d,",:,:,:)"
!!$
!!$       dummy3D(1:nx2,1:ny2,1:nz2) = cA2(d,1:nx2,1:ny2,1:nz2)
!!$
!!$       call fill_halo(lev+1, dummy3D)
!!$
!!$       cA2(d,:,:,:) =  dummy3D(:,:,:) * cff
!!$
!!$       ! a way of improvement (only if it impacts perfs):
!!$       ! copy from cA2 to dummy3 only the interior ring used to fill the halo
!!$       ! copy from dummy to cA2 only the halo
!!$    enddo

!    if (myrank.eq.0) write(*,*)"coarsening done"



  end subroutine coarsen_matrix_3D

end module mg_define_matrix

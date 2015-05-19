program test_bandpass

  use const
  use bandpass

  implicit none
  character(len=256) :: filter_list, my_data_dir, spectra_list
  character(len=16) :: suffix, arg
  integer :: count, choice, phot_system, ierr
  logical :: new_table_style = .true.
  !logical :: do_CNONa = .false., do_NGC6752 = .true., do_BTSettl=.false.
  integer, parameter:: num_Av = 1, num_Rv = 1
  !integer, parameter :: num_Av=10, num_Rv=1
  real(dp) :: Av(num_Av), Rv(num_Rv)
  
  ierr = 0
  
  !test - no reddening
  Rv=[3.1d0]
  Av=[0d0]

  !standard Av,Rv
  !Av = [ 0d0, 0.05d0, 0.1d0, 0.15d0, 0.2d0, 0.3d0, 0.4d0, 0.6d0, 0.8d0, 1d0 ]
  !Rv = [ 3.1d0 ]
  
  count = command_argument_count()
  
  my_data_dir='/home/dotter/science/Spectra'
  !my_data_dir='/coala/dotter/science/Spectra'
  
  call set_data_dir(my_data_dir)
      
  if(count>=2)then
     !process command line arguments
     call get_command_argument(1,arg)
     read(arg,*) choice
     call get_command_argument(2,arg)
     read(arg,*) phot_system
     
     if(choice>0) call get_command_argument(3,spectra_list)
     
     if(choice>0.and.count==4)then
        call get_command_argument(4,arg)
        if(trim(arg)=='old' .or. trim(arg)=='OLD') new_table_style=.false.
     endif

     call setup(phot_system)
     
     if(choice==VEGAZP)then
        call do_vega(filter_list,ierr)
     else
        call do_one_set(choice,filter_list,spectra_list,suffix,ierr)
     endif
  else
     call write_usage_details
  endif
  
contains
      
  subroutine do_vega(filter_list,ierr)
    character(len=256), intent(in) :: filter_list
    integer, intent(out) :: ierr
    character(len=13), pointer :: filter_name(:)
    type(spectrum) :: vega, AB, ST
    type(spectrum), allocatable :: filter_set(:)
    integer :: i, i0, i1, num_filters
    real(dp), allocatable :: Vega_ZP(:), ST_ZP(:), AB_ZP(:)
    
    ierr=0
    
    if(.not.data_dir_set)then
       write(*,*) 'data directory not set in grid_bandpass'
       ierr=-1
       return
    endif
      
    if(debug) write(*,*) '     read vega . . .'
    vega% filename=vega_filename
    AB% filename = vega_filename
    ST% filename = vega_filename
    write(0,*)"files: ",trim(vega% filename),trim(AB% filename),trim(ST% filename)
    call read_vega(vega,AB,ST,ierr)
    if(ierr/=0) stop 'failed in read_vega'
    if(debug)then
       write(*,*) '   filename = ', trim(vega% filename)
       write(*,*) '   npts = ', vega% npts
       write(*,*) vega% wave(1), vega% flux(1)
       write(*,*) vega% wave(vega% npts), vega% flux(vega% npts)
    endif
    
    if(debug) write(*,*) '      read filters . . .'
    call read_filters(filter_list,filter_set,num_filters,ierr)
    if(ierr/=0) stop 'failed in read_filters'
    
    allocate(Vega_ZP(num_filters),filter_name(num_Filters),ST_ZP(num_filters),AB_ZP(num_filters))

    if(debug) write(*,*) '     derive zeropoints . . .'
    write(*,'(a3,3x,a13,99a20)') 'i', 'filter', 'Vega ZP', 'ST ZP', 'AB ZP', 'mag(Vega/ST)', &
         'mag(Vega/AB)'
    do i=1,num_Filters !'
       i0 = index(filter_set(i)% filename, '/', .true.)+1
       i1 = index(filter_set(i)% filename, '.', .true.)-1
       filter_name(i) = filter_set(i)% filename(i0:i1)
       Vega_ZP(i) = integrate_bandpass(vega,filter_set(i),ierr)
       ST_ZP(i) = integrate_bandpass(ST,filter_set(i),ierr)
       AB_ZP(i) = integrate_bandpass(AB,filter_set(i),ierr)
       if(ierr/=0) stop 'failed in integrate_bandpass'
       write(*,'(i3,3x,a13,99f20.10)') i, filter_name(i), &
            Vega_ZP(i), ST_ZP(i), AB_ZP(i), &
            -2.5d0*log10(Vega_ZP(i)/ST_ZP(i)), &
            -2.5d0*log10(Vega_ZP(i)/AB_ZP(i))
    enddo
    
    deallocate(vega_zp,filter_name)

  end subroutine do_vega
  
  subroutine do_one_set(choice,filter_list,spectra_list,suffix,ierr)
    integer, intent(in) :: choice
    character(len=256), intent(in) :: filter_list, spectra_list
    character(len=16), intent(in) :: suffix
    integer, intent(out) :: ierr
    character(len=256) :: outfile, filename, prefix
    character(len=10), allocatable :: filter_name(:)
    type(spectrum) :: vega, AB, ST
    type(spectrum), allocatable :: filter(:)
    type(spectrum), pointer :: spectra(:)
    integer :: i, i0, i1, j, k, l, num_filters, num_spectra
    real(dp) :: tmp_mag
    real(dp), allocatable :: ZP(:)
    real(dp), pointer :: mag(:,:,:,:)
    logical :: AOK

    ierr=0

    if(.not.data_dir_set)then
       write(*,*) 'data directory not set in grid_bandpass'
       ierr=-1
       return
    endif

    if(debug) write(*,*) '     read vega . . .'
    vega% filename=vega_filename

    call read_vega(vega,AB,ST,ierr)
    if(ierr/=0) then 
       write(*,*) 'failed in read_vega'
       return
    endif

    if(debug)then
       write(*,*) '   filename = ', trim(vega% filename)
       write(*,*) '   npts = ', vega% npts
       write(*,*) vega% wave(1), vega% flux(1)
       write(*,*) vega% wave(vega% npts), vega% flux(vega% npts)
    endif

    if(debug) write(*,*) '      read filters . . .'
    call read_filters(filter_list,filter,num_filters,ierr)
    if(ierr/=0) then
       write(*,*) 'failed in read_filters'
       return
    endif

    allocate(ZP(num_filters),filter_name(num_Filters))

    if(debug) write(*,*) '     integrate bandpasses . . .'
    do i=1,num_Filters
       i0 = index(filter(i)% filename, '/', .true.)+1
       i1 = index(filter(i)% filename, '.', .true.)-1
       filter_name(i) = filter(i)% filename(i0:i1)
       select case(zero_point_type)
       case(zero_point_Vega)
          ZP(i) = integrate_bandpass(vega,filter(i),ierr)
       case(zero_point_ST)
          ZP(i) = integrate_bandpass(ST,filter(i),ierr)
       case(zero_point_AB)
          ZP(i) = integrate_bandpass(AB,filter(i),ierr)
       case default
          stop 'incorrect choice of zero point!'
       end select
       if(ierr/=0) then
          write(*,*) 'failed in integrate_bandpass'
          return
       endif

       if(debug) write(*,'(i3,3x,a30,2f20.10)') i, filter(i)% filename, ZP(i), -2.5d0*log10(ZP(i))
    enddo

    if(choice==BB) then
       filename = spectra_list
    else
       open(99,file=trim(spectra_list),iostat=ierr)
       if(ierr/=0) then
          write(*,*) 'failed to open spectra_list'
          return
       endif
    endif

    do while(.true.)
       if(choice/=BB)then
          read(99,'(a)',iostat=ierr) filename
          if(ierr/=0) exit ! iostat=-1 means end of file
          if(filename(1:1)=='#'.or.filename=='') cycle
       endif

       select case(choice)
       case(BB)
          if(debug) write(*,*) 'blackbody'
          prefix = filename
          !write(*,*) 'blackbody spectra with filename: ', trim(prefix)
          call create_BBs(spectra,num_spectra,ierr)
       case(CK2003)
          if(debug) write(*,*) 'CK2003'
          i0=index(filename,'  Z')
          prefix=trim(adjustl(filename(i0:)))
          filename = filename(:i0-1)
          write(*,*) trim(filename), ' ', trim(prefix)
          read_on_the_fly = .false.
          call read_ck2003(filename,spectra,num_spectra,ierr)
       case(PHOENIX:KOESTER)
          i0=index(filename,'/',back=.true.)+1
          i1=index(filename,'.',back=.true.)-1
          prefix=filename(i0:i1)
          write(*,*) trim(filename), ' ', trim(prefix)
          call read_spec(choice,filename,spectra,num_spectra,ierr)
       case default
          write(*,*) ' grid_bandpass/do_one_set: invalid choice of spectra'
          ierr=-1
          return
       end select

       if(ierr/=0)then
          write(*,*)
          write(*,*) ' I quit! '
          write(*,*)
          return
       endif

       nullify(mag)
       allocate(mag(num_filters,num_Av,num_Rv,num_spectra))

       !main loop where BCs are calculated
       if(debug) write(*,*) 'main loop'
       AOK = .true.
!$omp parallel do private(i,j,k,l)
       do i=1,num_spectra
!$omp critical
          if(read_on_the_fly) call load_spec(choice,spectra(i),ierr)
!$omp end critical
          if(ierr/=0) cycle
          do j=1,num_Rv
             do k=1,num_Av
                call extinction_for_spectrum(spectra(i),Av(k),Rv(j))
                do l=1,num_filters
                   tmp_mag = flux_ref_const*integrate_bandpass(spectra(i),filter(l),ierr) &
                        / (spectra(i)% Fbol * ZP(l))
                   mag(l,k,j,i) = Mbol_ref + 2.5d0*log10(tmp_mag)
                   if(ierr/=0) then
                      write(0,*) 'failed in integrate_bandpass'
                      write(0,*) ' file = ', trim(spectra(i)% filename)
                      AOK = .false.
                      exit
                   endif
                enddo !l-loop
             enddo !k-loop
          enddo !j-loop
!$omp critical
          if(choice/=CK2003.and.read_on_the_fly) call unload_spec(spectra(i),ierr)
!$omp end critical
       enddo
!$omp end parallel do

       if(.not.AOK) then
          write(0,*) "A complete flop and the worst thing I've ever done."
          return
       endif

       outfile=trim(prefix)//trim(suffix)
       write(0,*) '   output to ', trim(outfile)
       open(1,file=trim(outfile),iostat=ierr)
       if(ierr/=0) then
          write(*,*) 'failed to write output file'
          return
       endif
       if(new_table_style)then
          write(1,'(a1,1x,4a8)') '#', 'filters', 'spectra', 'num Av', 'num Rv'
          write(1,'(a1,1x,4i8)') '#', num_filters, num_spectra, num_Av, num_Rv
          write(1,'(a1)') '#'
          do j=1,num_Rv
             do k=1,num_Av
                write(1,2) '#', (i,i=1,num_filters+5)
                write(1,3) '#', 'Teff ', 'logg ', '[Fe/H]', '  Av ', '  Rv ', filter_name(1:num_filters)
                do i=1,num_spectra
                   write(1,4) spectra(i)% Teff, spectra(i)% logg, spectra(i)% FeH, Av(k), Rv(j), mag(:,k,j,i)
                enddo
                if(k<num_Av.and.j<num_Rv)then
                   write(1,*)
                   write(1,*)
                endif
             enddo
          enddo
       else !do the old table style, only one table per file and one value each of Av, Rv
          write(1,5) '#', (i,i=1,num_filters+3)
          write(1,6) '#', 'Teff ', 'logg ', '[Fe/H]', filter_name(1:num_filters)
          do i=1,num_spectra
             write(1,7) spectra(i)% Teff, spectra(i)% logg, spectra(i)% FeH, mag(:,1,1,i)
          enddo
       endif
       close(1)

       deallocate(mag,spectra)

       if(choice==BB) exit
    enddo

    if(choice/=BB) close(99)

    deallocate(filter,ZP,filter_name)

2   format(a1,i7, i5, 3i6, 99(5x,i2,5x))
3   format(a1,a7, a5, 3a6 ,99a12)
4   format(f8.0,f5.1,3f6.2,99f12.6)

5   format(a1,i7,i5,i6,99(5x,i2,5x))
6   format(a1,a7,a5,a6,99a12)
7   format(f8.0,f5.1,f6.2,99f12.6)

  end subroutine do_one_set

  subroutine setup(phot_system)
    integer, intent(in) :: phot_system
    
    select case(phot_system)
    case(HST_WFC3)
       write(*,*) ' doing HST/WFC3'
       filter_list = 'lists/wfc3_filter.list'
       suffix = '.HST_WFC3'
       zero_point_type = zero_point_Vega
    case(HST_ACS_WFC)
       write(*,*) ' doing HST/ACS-WFC'
       filter_list = 'lists/acs_wfc_filter.list'
       suffix = '.HST_ACSWF'
       zero_point_type = zero_point_Vega
    case(HST_ACS_HRC)
       write(*,*) ' doing HST/ACS-HRC'
       filter_list = 'lists/acs_hrc_filter.list'
       suffix = '.HST_ACSHR'
       zero_point_type = zero_point_Vega
    case(HST_WFPC2)
       write(*,*) ' doing HST/WFPC2'
       filter_list = 'lists/wfpc2_filter.list'
       suffix = '.HST_WFPC2'
       zero_point_type = zero_point_Vega
    case(SDSS)
       write(*,*) ' doing SDSS'
       filter_list = 'lists/SDSS_filter.list'
       suffix = '.SDSSugriz'
       zero_point_type = zero_point_AB
    case(CFHT)
       write(*,*) ' doing CFHT'
       filter_list = 'lists/CFHT_filter.list'
       suffix = '.CFHTugriz'
       zero_point_type = zero_point_AB
    case(UBVRIJHKsKp)
       write(*,*) ' doing UBVRI+2MASS+Kepler'
       filter_list = 'lists/UBVRIJHKsKpD51_filter.list'
       suffix = '.UBVRIJHKsKp'
       zero_point_type = zero_point_Vega
    case(WashDDOuvby)
       write(*,*) ' doing Washington+DDO51+Stroemgren'
       filter_list = 'lists/WashDDOuvby_filter.list'
       suffix = '.WashDDOuvby'
       zero_point_type = zero_point_Vega
    case(UKIDSS)
       write(*,*) ' doing UKIDSS'
       filter_list = 'lists/UKIDSS_filter.list'
       suffix = '.UKIDSS'
       zero_point_type = zero_point_Vega
    case(WISE)
       write(*,*) ' doing WISE'
       filter_list = 'lists/WISE_filter.list'
       suffix = '.WISE'
       zero_point_type = zero_point_Vega
    case(PanSTARRS)
       write(*,*) ' doing PanSTARRS'
       filter_list = 'lists/PanSTARRS1_filter.list'
       suffix = '.PanSTARRS'
       zero_point_type = zero_point_AB
    case(SPITZER)
       write(*,*) ' doing SPITZER'
       filter_list = 'lists/SPITZER_filter.list'
       suffix = '.SPITZER'
       zero_point_type = zero_point_Vega
    case(SkyMapper)
       write(*,*) ' doing SkyMapper'
       filter_list = 'lists/SkyMapper_filter.list'
       suffix='.SkyMapper'
       zero_point_type = zero_point_AB
    case(LSST)
       write(*,*) ' doing LSST'
       filter_list = 'lists/LSST_filter.list'
       suffix='.LSST'
       zero_point_type = zero_point_AB
    case(Swift)
       write(*,*) ' doing Swift UVOT'
       filter_list = 'lists/swift.list'
       suffix='.Swift'
       zero_point_type = zero_point_AB
    case(FSPS)
       write(*,*) ' doing FSPS'
       filter_list='lists/fsps.list'
       suffix='.FSPS'
       zero_point_type=zero_point_AB
    case(DECam)
       write(*,*) ' doing DECam'
       filter_list='lists/DECam_filter.list'
       suffix='.DECam'
       zero_point_type=zero_point_AB
    case default
       filter_list = ''
       suffix = ''
       zero_point_type = 0
    end select
    
  end subroutine setup
  
  subroutine write_usage_details
    write(*,*) ' usage: ./grid_bandpass [M] [N] [list]'
    write(*,*) '                      '
    write(*,*) '        M = 0 - 7     '
    write(*,*) ' Vega/AB/ST ZPs =  0  '
    write(*,*) ' Blackbody      =  1  '
    write(*,*) ' Castelli&Kurucz=  2  '
    write(*,*) ' PHOENIX        =  3  '
    write(*,*) ' SYNTHE high res=  4  '
    write(*,*) ' SYNTHE  low res=  5  '
    write(*,*) ' RAUCH post-AGB =  6  ' 
    write(*,*) ' Koester DA WDs =  7  '
    write(*,*) '                      '
    write(*,*) '        N = 1 - 16    '
    write(*,*) ' HST_WFC3       =  1  '
    write(*,*) ' HST_ACS_WFC    =  2  '
    write(*,*) ' HST_ACS_HRC    =  3  '
    write(*,*) ' HST_WFPC2      =  4  '
    write(*,*) ' SDSS           =  5  '
    write(*,*) ' CFHT/MegaCam   =  6  '
    write(*,*) ' UBVRIJHKsKp    =  7  '
    write(*,*) ' WashDDOuvby    =  8  '
    write(*,*) ' UKIDSS         =  9  '
    write(*,*) ' WISE           = 10  '
    write(*,*) ' PanSTARRS      = 11  '
    write(*,*) ' SPITZER        = 12  '
    write(*,*) ' SkyMapper      = 13  '
    write(*,*) ' LSST           = 14  '
    write(*,*) ' Swift          = 15  '
    write(*,*) ' FSPS           = 16  '
    write(*,*) ' DECam          = 17  '
    write(*,*)
    
  end subroutine write_usage_details
  
end program test_bandpass
